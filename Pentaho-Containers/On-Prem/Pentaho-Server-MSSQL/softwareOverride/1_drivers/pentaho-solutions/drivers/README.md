# Big Data Drivers Directory

## Purpose

This directory is for Pentaho Big Data driver plugins (.kar files). These drivers enable connectivity to big data platforms such as Hadoop, Spark, and other distributed systems.

## Important Note

Big data drivers are **not included** by default. You must download them individually from the Pentaho support portal if needed.

## Download Instructions

1. Visit the Pentaho Support Portal: https://support.pentaho.com/hc/en-us
2. Navigate to the drivers download section
3. Download the required big data driver archive
4. Unzip the archive
5. Run the installer
6. Place the resulting `.kar` file in this directory
7. Restart the Pentaho Server

## Custom Driver Location

If you prefer to store driver files in a different location:

1. Copy the driver `.kar` files to your desired location
2. Edit the `kettle.properties` file
3. Update the `SHIM_DRIVER_DEPLOYMENT_LOCATION` property with the full path to your driver location

```properties
SHIM_DRIVER_DEPLOYMENT_LOCATION=/path/to/your/drivers
```

## Supported Big Data Platforms

Common big data drivers include:

| Platform | Description |
|----------|-------------|
| Hadoop | Apache Hadoop ecosystem |
| Spark | Apache Spark processing |
| HBase | Apache HBase NoSQL database |
| Hive | Apache Hive data warehouse |
| Impala | Cloudera Impala query engine |

## Related Documentation

- [1_drivers/README.md](../../README.md) - JDBC drivers documentation
- [Main README.md](../../../../README.md) - Project documentation
- [CONFIGURATION.md](../../../../CONFIGURATION.md) - Configuration reference
