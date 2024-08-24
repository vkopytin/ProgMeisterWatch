import Toybox.Lang;
import Toybox.System;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Position;

var actions = [];
var state = {
    :battery => {
        :level => 0,
        :charging => false,
        :batteryInDays => 0,
        :solarIntensity => 0,
        :solarStatusIcon => "5",
        :isSolarCharging => false,
        :solarColor => 0x55ffff,
    },
    :heartRate => {
        :heartRate => "0",
    },
    :steps => {
        :steps => "0",
    },
    :heading => {
        :heading => 0,
    },
    :bodyBattery => {
        :bodyBattery => "100",
    },
    :stress => {
        :stress => "100",
    },
};

var randomType = 1000;
enum ActionTypes {
    UPDATE_BATTERY = "UPDATE_BATTERY",
    UPDATE_HEART_RATE = "UPDATE_HEART_RATE",
    UPDATE_STEPS = "UPDATE_STEPS",
    UPDATE_HEADING = "UPDATE_HEADING",
    UPDATE_BODY_BATTERY = "UPDATE_BODY_BATTERY",
    UPDATE_STRESS = "UPDATE_STRESS",
}

function update(state, action) {
    switch (action[:type]) {
        case UPDATE_BATTERY:
            state[:battery] = {
                :level => action[:payload][:level],
                :charging => action[:payload][:charging],
                :batteryInDays => action[:payload][:batteryInDays],
                :solarIntensity => action[:payload][:solarIntensity],
                :solarStatusIcon => action[:payload][:solarStatusIcon],
                :isSolarCharging => action[:payload][:isSolarCharging],
                :solarColor => action[:payload][:solarColor],
            };
            return state;
        case UPDATE_HEART_RATE:
            state[:heartRate] = {
                :heartRate => action[:payload][:heartRate],
            };
            return state;
        case UPDATE_STEPS:
            state[:steps] = {
                :steps => action[:payload][:steps],
            };
            return state;
        case UPDATE_HEADING:
            state[:heading] = {
                :heading => action[:payload][:heading],
            };
            return state;
        case UPDATE_BODY_BATTERY:
            state[:bodyBattery] = {
                :bodyBattery => action[:payload][:bodyBattery],
            };
            return state;
        case UPDATE_STRESS:
            state[:stress] = {
                :stress => action[:payload][:stress],
            };
            return state;
        default:
            return state;
    }
}

function dispatch(action) {
    actions.add(action);
    state = getState();
}

function getState() {
    var oldActions = actions;
    actions = [];
    for (var i = 0; i < oldActions.size(); i++) {
        state = update(state, oldActions[i]);
    }
    return state;
}

function dispatchUpdateButtery() {
    var stats = System.getSystemStats();
    var enabledColor = 0x005555;
    var disabledColor = 0x55ffff;
    var color = disabledColor;
    var solarStatusIcon = "5";
    var solarIntensity = stats.solarIntensity;
    var isSolarCharging = stats.solarIntensity > 0;
    if (solarIntensity > 49) {
        color = enabledColor;
        solarStatusIcon = "7";
    } else if (solarIntensity > 24) {
        color = enabledColor;
        solarStatusIcon = "6";
    } else if (solarIntensity > 0) {
        color = enabledColor;
        solarStatusIcon = "5";
    } else {
        color = disabledColor;
        solarStatusIcon = "5";
    }

    dispatch({
        :type => UPDATE_BATTERY,
        :payload => {
            :level => stats.battery,
            :charging => stats.charging,
            :batteryInDays => stats.batteryInDays,
            :solarIntensity => solarIntensity,
            :solarStatusIcon => solarStatusIcon,
            :isSolarCharging => isSolarCharging,
            :solarColor => color,
        },
    });
}

function dispatchUpdateHeartRate() {
    var activityInfo = Activity.getActivityInfo();
    var heartRate = activityInfo.currentHeartRate;
    if (heartRate == null) {
        var HRH = ActivityMonitor.getHeartRateHistory(1, true);
        var HRS = HRH.next();
        if(HRS != null && HRS.heartRate != ActivityMonitor.INVALID_HR_SAMPLE){
            heartRate = HRS.heartRate;
        }
    }

    if (heartRate == null) {
        return;
    }

    dispatch({
        :type => UPDATE_HEART_RATE,
        :payload => {
            :heartRate => heartRate.format("%02d"),
        },
    });
}

function dispatchUpdateSteps() {
    var activityInfo = ActivityMonitor.getInfo();

    dispatch({
        :type => UPDATE_STEPS,
        :payload => {
            :steps => activityInfo.steps.format("%02d"),
        },
    });
}

function dispatchUpdateHeading() {
    var position = Position.getInfo();
    var info = Activity.getActivityInfo();
    var heading = info == null || info.currentHeading == null ? position.heading : info.currentHeading;

    dispatch({
        :type => UPDATE_HEADING,
        :payload => {
            :heading => heading,
        },
    });
}

function dispatchUpdateBodyBattery() {
    var bbIterator = Toybox.SensorHistory.getBodyBatteryHistory({ :period => 1 });
    var sample = bbIterator.next();

    if (sample == null) {
        return;
    }

    var pwr = sample.data;

    dispatch({
        :type => UPDATE_BODY_BATTERY,
        :payload => {
            :bodyBattery => pwr.format("%02d"),
        },
    });
}

function dispatchUpdateStress() {
    var stressIterator = Toybox.SensorHistory.getStressHistory({ :period => 1 });
    var sample = stressIterator.next();
    if (sample == null) {
        return;
    }

    var stress = sample.data;

    dispatch({
        :type => UPDATE_STRESS,
        :payload => {
            :stress => stress.format("%02d"),
        },
    });
}