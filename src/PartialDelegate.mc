import Toybox.WatchUi;
import Toybox.System;

function partialDelegateCreate() as PartialDelegate {
    var inst = new PartialDelegate();
    return inst;
}

class PartialDelegate extends WatchUi.WatchFaceDelegate
{
	function initialize() {
		WatchFaceDelegate.initialize();
	}
    function onPowerBudgetExceeded(powerInfo) {
        System.println( "Average execution time: " + powerInfo.executionTimeAverage );
        System.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
    }
}
