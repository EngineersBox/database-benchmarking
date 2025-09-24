import groovy.jmx.GroovyMBean
import groovy.transform.EqualsAndHashCode
import javax.management.ObjectName
import java.lang.Runnable
import java.io.File
import java.util.ArrayList
import java.util.Properties
import java.util.concurrent.TimeUnit

/* =============================
 *     AUTO-INSTRUMENTATION
 * =============================
 */

class Cache {

  @EqualsAndHashCode
  static class Key {
      String domain;
      String name;
      String type;
      Set<String> labels;
      String metricClass; // JmxGauge, JmxTimer, etc

      String toIndentedString(final String indent) {
        String labelNames = this.labels.collect({
            label -> "${indent}    ${label}"
        }).join(",\n")
        String labelsFormat = this.labels.isEmpty()
            ? "${indent}  Labels: [],"
            : """${indent}  Labels: [
${labelNames}
${indent}  ]"""
        return """${indent}Key: {
${indent}  Domain: ${this.domain},
${indent}  Name: ${this.name},
${indent}  Type: ${this.type},
${labelsFormat}
${indent}  Metric Class: ${this.metricClass}
${indent}}""";
      }
  }

  @EqualsAndHashCode
  static class Attribute {
      String name;
      String desc;
      String unit;
      Map<String, Closure> labelMappings; // Map of String to Closure
      String callbackType;
      Closure callback;

      String toIndentedString(final String indent) {
        String lindent = "${indent}    ";
        String labels = this.labelMappings.collect({
            label, closure -> "${lindent}${label}"
        }).join(",\n");
        String labelsFormat = this.labelMappings.isEmpty()
            ? "${indent}  Labels: [],"
            : """${indent}  Labels: [
${labels}
${indent}  ]"""
        return """{
${indent}  Name: ${this.name},
${indent}  Desc: ${this.desc},
${indent}  Unit: ${this.unit},
${labelsFormat}
${indent}  Callback Type: ${this.callbackType}
${indent}}""";
      }

  }

  @EqualsAndHashCode
  static class Entry {
      Set<String> objectNames;
      Map<String, Cache.Attribute> attributes
    
      String toIndentedString(final String indent) {
          String objectNamesString = this.objectNames.collect({
              on -> "${indent}    ${on}"
          }).join(",\n");
          String aindent = "${indent}    ";
          String attributesString = this.attributes.collect({
              name, attribute -> "${aindent}${name}: ${attribute.toIndentedString(aindent)}"
          }).join(",\n");
          return """${indent}Entry: {
${indent}  Object Names: [
${objectNamesString}
${indent}  ],
${indent}  Attributes: {
${attributesString}
${indent}  }
${indent}}""";
      }
  }

  static Map<Cache.Key, Cache.Entry> mbeanMappings = [:]
  static long lastPoll = System.nanoTime();
  static final long pollFreq = TimeUnit.SECONDS.toNanos(10);

  static def printCache() {
      Cache.mbeanMappings.each({ key, entry ->
          System.err.println("""{
${key.toIndentedString("  ")}
${entry.toIndentedString("  ")}
}""");
      })
  }
}

@EqualsAndHashCode
class ConditionalAttributes {
    Set<String> trueExclusionAttributes;
    Set<String> falseExclusionAttributes;
}

def camelToSnake(final String str) {
  def regex = "([a-z])([A-Z]+)";
  def replacement = "\$1_\$2";
  return str.replaceAll(regex, replacement).toLowerCase();
}

def resolveGaugeValueType(final GroovyMBean bean) {
  def value = bean.getProperty("Value")
  def clazz = value.getClass()
  def typeName = clazz.getName().replace(
    "${clazz.getPackageName()}.",
    ""
  )
  return "${Character.toLowerCase(typeName.charAt(0))}${typeName.substring(1)}"
}

def enforceNaming(final String str) {
    return str == null ? "" : "." + str.replaceAll("\s", "_")
        .replaceAll("[^a-zA-Z0-9_]+", "_")
}

def constructName(final String domain,
                  final String propertyType,
                  final String propertyName,
                  final String attributeName) {
  def formattedPropertyType = enforceNaming(propertyType)
  def formattedPropertyName = enforceNaming(propertyName)
  return "${domain}${formattedPropertyType}${formattedPropertyName}.${attributeName}"
}

def formatDescSection(final String section) {
  return section == null ? "" : "${section} "
}

def cacheMBean(final GroovyMBean bean,
               final Map<String, String> nameMappings,
               final Map<String, ConditionalAttributes> conditionalAttributes) {
  def callbackMappings = [
    "double": otel.&doubleValueCallback,
    "long": otel.&doubleValueCallback,
    "integer": otel.&doubleValueCallback,
    // "[D": otel.&doubleHistogram,
    // "[J": otel.&longHistogram,
    // "java.lang.Object": otel.&longCounterCallback
  ]
  def beanInfo = bean.info()
  def attributes = bean.listAttributeNames()
  def beanName = bean.name()
  def metricClassSplit = beanInfo.getClassName().tokenize('$')
  final String metricClass = metricClassSplit.last()
  final boolean isGauge = metricClass == "JmxGauge"
  final String domain = beanName.getDomain()
  final String propertyType = beanName.getKeyProperty("type")
  final String propertyName = beanName.getKeyProperty("name")
  def labelMappings = beanName.getKeyPropertyList()
    .findAll({ k,v -> k != "type" && k != "name" })
    .collectEntries({ k,v -> [(k): { mbean -> mbean.name().getKeyProperty(k) }] })
  final Cache.Key key = new Cache.Key(
      domain: domain,
      name: propertyName,
      type: propertyType,
      labels: labelMappings.collect({ k,v -> k}),
      metricClass: metricClass
  );
  Cache.Entry entry = Cache.mbeanMappings.computeIfAbsent(key, { k -> new Cache.Entry(
      objectNames: [],
      attributes: [:]
  )});
  entry.objectNames.add(beanName.toString());
  def beanAttributes = conditionalAttributes == null
      ? beanInfo.getAttributes()
      : beanInfo.getAttributes()
          .findAll({ attribute -> !conditionalAttributes.containsKey(attribute.getName()) })
  conditionalAttributes?.each({
      cond, attrs ->
      if (bean.getProperty(cond)) {
          beanAttributes = beanAttributes.findAll({ beanAttribute ->
              return !attrs.trueExclusionAttributes.contains(beanAttribute.getName())
          })
      } else {
          beanAttributes = beanAttributes.findAll({ beanAttribute ->
              return !attrs.falseExclusionAttributes.contains(beanAttribute.getName())
          })
      }
  })
  beanAttributes.each({ attribute ->
    def mappingLookupKey = isGauge || attribute?.getType() == "java.lang.Object"
        ? resolveGaugeValueType(bean)
        : attribute.getType()
    def callback = callbackMappings[mappingLookupKey]
    if (callback == null) {
      return
    }
    def attributeName = attribute.getName()
    entry.attributes.putIfAbsent(attributeName, new Cache.Attribute(
        name: camelToSnake(constructName(
            nameMappings[domain],
            propertyType,
            propertyName,
            attributeName
        )),
        desc: "${formatDescSection(propertyType)}${formatDescSection(propertyName)}${attributeName}",
        unit: "1",
        labelMappings: labelMappings,
        callbackType: mappingLookupKey,
        callback: callback
    ));
  })
  if (entry.attributes.isEmpty()) {
      final String attributeNames = beanInfo.getAttributes()
          .collect({ attribute -> attribute.getName() })
          .join(", ")
      System.err.println(
          "[WARNING] No instrumentable attributes found for ObjectName \"${beanName.toString()}\", skipping. Attributes were: [${attributeNames}]"
      )
      Cache.mbeanMappings.remove(key);
  }
}

def cacheMBeans(final String objectName,
                final Map<String, String> nameMappings,
                final List<ObjectName> excludeObjectNames = [],
                final Map<ObjectName, Map<String, ConditionalAttributes>> includeAttributesCond = [:]) {
  def mbeans = otel.queryJmx(objectName)
  mbeans.findAll({
    mbean -> 
        final ObjectName mbeanName = mbean.name()
        return !excludeObjectNames.any({ exclude -> exclude.apply(mbeanName) })
  }).each({
     mbean ->
        final ObjectName mbeanName = mbean.name()
        return cacheMBean(
            mbean,
            nameMappings,
            includeAttributesCond.find({
                name, _cond -> name.apply(mbeanName)
            })?.getValue()
        )
  })
}

def instrumentMBeans() {
  // TODO: Get the node id as a property passed via CLI invocation
  //       via System.getProperty(...) and tag eacb of the MBeans
  //       with it so that multi-node JMX setups can distinguish
  //       between nodes at a metric level.
  Cache.mbeanMappings.each({ key, entry ->
      def mbeans = otel.mbeans((entry.objectNames) as ArrayList);
      entry.attributes.each({ name, attribute ->
          otel.instrument(
              mbeans,
              attribute.name,
              attribute.desc,
              attribute.unit,
              attribute.labelMappings,
              name,
              attribute.callback
          );
      })
  })
}

/* =============================
 *         APPLICATIONS
 * =============================
 */

def cassandra() {
  def nameMappings = [
      "org.apache.cassandra.metrics": "cassandra",
      "org.apache.cassandra.metrics.scheduler": "cassandra_scheduler"
  ]
  //cacheMBeans("org.apache.cassandra.metrics:type=Cache,*", nameMappings)
  //cacheMBeans("org.apache.cassandra.metrics:type=BufferPool,*", nameMappings)
  cacheMBeans("org.apache.cassandra.metrics.scheduler:type=ThreadPools,*", nameMappings)
  cacheMBeans("org.apache.cassandra.metrics.scheduler:type=SharedExecutorPool,*", nameMappings)
  cacheMBeans("org.apache.cassandra.metrics.scheduler:type=SEPWorker,*", nameMappings)
  cacheMBeans("org.apache.cassandra.metrics:type=StorageProxy,*", nameMappings)
  //cacheMBeans("org.apache.cassandra.metrics:type=ColumnFamily,*", nameMappings)
}

def hbase() {
    // TODO: Implement this
}

/* =============================
 *             JVM
 * =============================
 */

def cacheJVMMBeans() {
    def nameMappings = [
        "java.lang": "jvm"
    ]
    def conditions = [
        (new ObjectName("java.lang:type=MemoryPool,*")): [
            "CollectionUsageThresholdSupported": new ConditionalAttributes(
                trueExclusionAttributes: [],
                falseExclusionAttributes: [
                    "CollectionUsage",
                    "CollectionUsageThreshold",
                    "CollectionUsageThresholdCount",
                    "CollectionUsageThresholdExceeded"
                ]
            ),
            "UsageThresholdSupported": new ConditionalAttributes(
                trueExclusionAttributes: [],
                falseExclusionAttributes: [
                    "Usage",
                    "UsageThreshold",
                    "UsageThresholdCount",
                    "UsageThresholdExceeded"
                ]
            )
        ]
    ]
    cacheMBeans("java.lang:*", nameMappings, [], conditions)
}

/* =============================
 *          INVOCATION
 * =============================
 */

def instrument() {
    final Properties properties = new Properties();
    new File("/otel-lgtm/jmx-beans.properties").withInputStream({
        properties.load(it);
    })
    final String application = properties.getProperty("application");
    if (application == null) {
        throw new IllegalStateException("Execpted an 'application' property");
    }
    final Closure applicationFn =[
        "cassandra": { -> cassandra() },
        "hbase": { -> hbase() },
    ][application];
    if (applicationFn == null) {
        throw new IllegalStateException("Unknown application: $application")
    }
    //final long now = System.nanoTime();
    //if (now - Cache.lastPoll >= Cache.pollFreq) {
    if (Cache.mbeanMappings.isEmpty()) {
        //Cache.lastPoll = now;
        applicationFn();
        cacheJVMMBeans();
        Cache.printCache();
    }
    instrumentMBeans()
}

instrument()
