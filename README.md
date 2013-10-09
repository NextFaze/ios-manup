# ManUp

A useful class to add a server side check for a mandatory update and server-side configuration options to your iOS application.

To add to you app, simply add the following lines to your AppDelegate class:

	- (void)applicationDidBecomeActive:(UIApplication *)application
	{
	    [ManUp manUpWithDefaultJSONFile:[[NSBundle mainBundle] pathForResource:@"config_manup" ofType:@"json"]
	                    serverConfigURL:[NSURL URLWithString:@"https://raw.github.com/NextfazeSD/ManUp/master/Example/ManUpDemo/ManUpDemo/TestFiles/test_Link_UpgradeAvailable.json"]
	                           delegate:self
	      minimumIntervalBetweenUpdates:5*60 /*5mins*/];
	}

Sample config file:

	{
		"version": "1",
		"ManUpMaintenanceMode": false,
		"ManUpAppUpdateLink": "https://itunes.apple.com/app/id0000000?mt=8",
		"ManUpAppVersionCurrent": "1",
		"ManUpAppVersionMin": "1"
	}
