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
