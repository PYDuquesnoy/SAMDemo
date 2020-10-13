# Workshop: System Management and Monitoring 



For a general overview of the SAM Architecture, see the PDF "02_Observability_Audit_Monitoring".



The following Workshop can be run on any platform that supports docker. Is has been tested on Docker for Linux and Docker for Windows.



## Clone this Repo into a local directory

```
git clone <this repository>
```

and cd into this directory...

the subdirectory sam-1.0.0.115-unix contains the docker-compose to start all SAM components and some startup and shutdown scripts for unix. We won't use these shell scripts on Windows. 

## Preparation Steps

In Linux, the config/prometheus directory needs to allow access, so you need to change its permissions to 777:

```
chmod 777 ./sam-1.0.0.115-unix/config/prometheus
```



## Start SAM and Connect to it

If running on linux, Start/Stop SAM with the start.sh and stop.sh scripts located in .\sam-1.0.0.0.115-unix\. You need to allow the scrits to execute:

```
chmod +x *.sh
```

On Windows, Start/Stop SAM with

```
.\sam-1.0.0.115-unix\docker-compose -p sam up 
or, for background:
.\sam-1.0.0.115-unix\docker-compose -p sam up -d
```

In Windows, you'll get a popup asking to allow the FileSharing between your Windows host and docker, and you need to accept.

You should see the SAM components starting up:

```
Creating sam_iris_1 ... done
Creating sam_prometheus_1 ... done
Creating sam_alertmanager_1 ... done
Creating sam_grafana_1      ... done
Creating sam_nginx_1        ... done
```



Connect to the System Management portal of the IRIS Instance within SAM, to change the password for _SYSTEM/SYS:

```
 http://127.0.0.1:8080/csp/sys/UtilHome.csp
```

Now, Connect to the main application (using _SYSTEM / <New Password>)

```
 http://127.0.0.1:8080/api/sam/app/index.csp
```



Before continuing the demo, we want to add an IRIS Instance to monitor. We'll use an InterSystems community instance, and start it is the same docker network as the SAM.

```
cd ./servertomonitor
docker-compose up -d
```

This instance can be reached as 

| From Within the Docker Network         | From the Windows Host                       |
| -------------------------------------- | ------------------------------------------- |
| http://iris:52773/csp/sys/UtilHome.csp | http://127.0.0.1:42773/csp/sys/UtilHome.csp |

Now, login to the Management portal of this instance (_SYSTEM /  SYS):

```
http://127.0.0.1:42773/csp/sys/UtilHome.csp
```

 

## Monitor an Instance

In the SAM portal,  select "Create your first Cluster", add a name "singleinstance" and a Description. Click "Add Cluster".

Now, add an Instance with the "new Button". The IRIS Instance to monitor has been started with hostname "servertomonitor_iris_1", using the webPort 52773 (internally to the docker Network, but exposed to our Windows host as 127.0.0.1:42773), and its instance name is IRIS:

```
IP: iris
Port: 52773
Instance Name: iris
```

After a few seconds, the instance should appear as reachable and OK!



## Add an Alert Rule for the Cluster

Edit the Cluster, Add Alert Rule:

```
Name: GloRefs>50000

Alert Severity: Warning

Alert Expression:  iris_glo_ref_per_sec{cluster="singleinstance"} > 50000

Alert message: High number of Global References per second
```



### Generate some load in the IRIS Instance

Log into the Iris instance

```
docker exec -it servertomonitor_iris_1 iris session iris
```

And create some globals

```
USER> for i=1:1:9000000 set ^MyTest(i)="" write:(i#10000=0) i," "
```

The Main monitor in SAM should now show an alert.



### Try other Alert expression examples:

You may want to try some other alert expressions, like these:

```
# Greater than 80 percent of InterSystems IRIS licenses are in use:
iris_license_percent_used{cluster="production"}>80

# There are less than 5 active InterSystems IRIS processes:
iris_process_count{cluster="test"}<5

# The disk storing the MYDATA database is over 75% full:
iris_disk_percent_full{cluster="test",id="MYDATA"}>75

# Same as above, but specifying directory instead of database name:
iris_disk_percent_full{cluster="production",dir="/IRIS/mgr/MYDATA"}>75

```



### Create an Error (Lock Table Full)

Also, any Warning or critical error in the IRIS instance gets propagated as an Alert to SAM.  To try this out, we can gee

Open a terminal 

```
 docker exec -it servertomonitor_iris_1 iris session iris
```

And Run Following:

```
USER> for i=1:1 lock +^Test(i,"This is a long Subscript to fill the table faster") w:(i#1000)=0 i,"  "
```

This will generate a "Lock Table Full", which will appear in SAM.

Clear the lock before continuing:

```
USER>lock
```



## Creating an Application Metric

Note: Following preparation step (loading the metric code in IRIS USER namespace) has already been performed in the Dockerfile that builds the servertomonitor container. You would need to perform them manually as described here if you use your own IRIS instance for testing:

Use an IDE (Studio to 127.0.0.1:41773, or VSCode to 127.0.0.1:42773) to connect to the IRIS Instance, and load/Compile following class:

```
/// Example of a custom class for the /metric API
Class SAMDemo.RandomMetric Extends %SYS.Monitor.SAM.Abstract
{

Parameter PRODUCT = "SAMDemo";

/// Collect metrics from the specified sensors
Method GetSensors() As %Status
{
   do ..SetSensor("MyRandomCounter",$Increment(^MyRandomCounter,$random(20)-5))
   return $$$OK
}

}

```



To make this metric available, Add the custom class to the /metrics configuration with following command:

```
docker exec -it servertomonitor_iris_1 iris session iris
zn "%SYS"
set sc=##class(SYS.Monitor.SAM.Config).AddApplicationClass("SAMDemo.RandomMetric","USER")
write sc
```



Very Important:

Add Privileges to the /api/Monitor REST Application to run code in the USER Namespace. (Add Application Role %DB_USER, otherwise it does not work.)

Review the Metric endpoint with a browser, and Verify that the new metric is present.( If not, review the Audit Database for a possible "Protect" error).

```
http://127.0.0.1:42773/api/monitor/metrics
```



## Using the Metric

The Custom metric (SAMDemo_my_random_counter) is ready to be added to customized using the Grafana dashboard.

