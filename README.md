# vera-rest
REST API reader for vera
- UPnP Device RestHandler
- UPnP Service HandleRest
- UPnP Action handleRest
  - Parameters:
    - xParam - Parameters to be sent either to URL or payload depending on xType
	- xType - GET or POST
	- xSamplePeriod - How often should REST API be called, if set to 0, then next job will NOT be scheduled

- UPnP variables
  - restUrl:  resource url eg. http://192.168.1.16:3500/inputs
  - outputObjectName: object storing resulting variable.
    - Examples:
	  - { value : "resultVal"} =>  outputObjectName := "value"
	  - { innerObject: { result : "100"} } => outputObjectName := "innerObject.result"
	- outputObjectValue - variable to store result 
	  - Restult from previous examples:
	    - outputObjectValue := "resultVal"
		- outputObjectValue := "100"
	- inputObjectName - resource parameter or payload
	- inputObjectType - GET/POST
	
	- Examples:
	  1. Option
	    - inputObjectName := "ADC01"
	    - inputObjectType := "GET"  
		   GET /inputs/ADC01 HTTP/1.1  
		   Host: 192.168.1.16:3500   
	  2. Option 	
	    - inputObjectName := '{"resourcename" : "ADC01"}'  
		- inputObjectType := "POST"  
		   POST /inputs/ADC01 HTTP/1.1  
		   Host: 192.168.1.16:3500  
		   Content-Type: application/json  
		
		   { "resourcename" : "ADC01"}  
  - samplePeriod - How often should REST API be called, if set to 0, then next job will NOT be scheduled

Control
-------
- Start polling by start button
- Stop polling by Set/stop button