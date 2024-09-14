import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Weather;
import Toybox.Time;
import Toybox.Application;
import Toybox.Graphics;
using Toybox.Time.Gregorian as Date;

const DAYS = {
    Date.DAY_MONDAY => "MON",
    Date.DAY_TUESDAY => "TUE",
    Date.DAY_WEDNESDAY => "WED",
    Date.DAY_THURSDAY => "THU",
    Date.DAY_FRIDAY => "FRI",
    Date.DAY_SATURDAY => "SAT",
    Date.DAY_SUNDAY => "SUN"
};

const MONTHS = {
    Date.MONTH_JANUARY => "JAN",
    Date.MONTH_FEBRUARY => "FEB",
    Date.MONTH_MARCH => "MAR",
    Date.MONTH_APRIL => "APR",
    Date.MONTH_MAY => "MAY",
    Date.MONTH_JUNE => "JUN",
    Date.MONTH_JULY => "JUL",
    Date.MONTH_AUGUST => "AUG",
    Date.MONTH_SEPTEMBER => "SEP",
    Date.MONTH_OCTOBER => "OCT",
    Date.MONTH_NOVEMBER => "NOV",
    Date.MONTH_DECEMBER => "DEC"
};

const WEATHER_ICON_MAPPER = {
    "01d" => "",
    "02d" => "",
    "03d" => "",
    "04d" => "",
    "09d" => "",
    "10d" => "",
    "11d" => "",
    "13d" => "",
    "50d" => "",

    "01n" => "",
    "02n" => "",
    "03n" => "",
    "04n" => "",
    "09n" => "",
    "10n" => "",
    "11n" => "",
    "13n" => "",
    "50n" => "",
};

class WatchFaceView extends WatchUi.WatchFace {
    static const timeTemplate = "$1$ $2$";
    static const timeAltTemplate = "$1$:$2$";
    static const RAD_90_DEG = 1.570796;

    private var timer = MainTimer.create(self);
    private var sleepMode = false;
    private var clockView = null as Toybox.WatchUi.Text?;
    private var timeSeparator = null as Toybox.WatchUi.Text?;
    private var currentDay = null as Toybox.WatchUi.Text?;
    private var currentDayName = null as Toybox.WatchUi.Text?;
    private var labelAmPm = null as Toybox.WatchUi.Text?;
    private var heartRate = null as Toybox.WatchUi.Text?;
    private var stepsView = null as Toybox.WatchUi.Text?;
    private var debugLabel = null as Toybox.WatchUi.Text?;
    private var energyLabel = null as Toybox.WatchUi.Text?;
    private var stressLabel = null as Toybox.WatchUi.Text?;
    private var pieChart = null as Toybox.WatchUi.Text?;

    private var graphView = null as GraphView?;
    private var graphPixelView = null as GraphPixelView?;
    private var dayNightView = null as DayNightView?;
    private var sunRiseSunSet = null as SunRiseSunSetView?;

    private var secondHand = null as WatchUi.BitmapResource?;
    private var minuteHand = null as WatchUi.BitmapResource?;
    private var hourHand = null as WatchUi.BitmapResource?;
    private var compassNeedle = null as WatchUi.BitmapResource?;

    private var secondHandTransform = new Graphics.AffineTransform();
    private var minuteHandTransform = new Graphics.AffineTransform();
    private var hourHandTransform = new Graphics.AffineTransform();
    private var compassAngleTransform = new Graphics.AffineTransform();

    private var displayInfo = [130, 130, 260, 260] as Array<Number>;

    private var buffer = null as Graphics.BufferedBitmap?;
    private var lastHour = -1;
    private var drawDelay = 1000;
    private var fakePieChartValue = 0;

    function initialize() {
        WatchFace.initialize();
        self.secondHand = WatchUi.loadResource(Rez.Drawables.SecondHand);
        self.hourHand = WatchUi.loadResource(Rez.Drawables.HourHand);
        self.minuteHand = WatchUi.loadResource(Rez.Drawables.MinuteHand);
        self.compassNeedle = WatchUi.loadResource(Rez.Drawables.CompassNeedle);
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        dc.setAntiAlias(true);
        setLayout(Rez.Layouts.WatchFace(dc));

        clockView = View.findDrawableById("TimeLabel") as Toybox.WatchUi.Text;
        timeSeparator = View.findDrawableById("TimeSeparator") as Toybox.WatchUi.Text;
        currentDay = View.findDrawableById("CurrentDay") as Toybox.WatchUi.Text;
        currentDayName = View.findDrawableById("CurrentDayName") as Toybox.WatchUi.Text;
        labelAmPm = View.findDrawableById("AMPM") as Toybox.WatchUi.Text;
        heartRate = View.findDrawableById("HeartRate") as Toybox.WatchUi.Text;
        stepsView = View.findDrawableById("Steps") as Toybox.WatchUi.Text;
        graphView = View.findDrawableById("bGraphDisplay") as GraphView;
        graphPixelView = View.findDrawableById("graphPixelView") as GraphPixelView;
        debugLabel = View.findDrawableById("debugLabel") as Toybox.WatchUi.Text;
        dayNightView = View.findDrawableById("dayNight") as DayNightView;
        sunRiseSunSet = View.findDrawableById("SunRiseSunSet") as SunRiseSunSetView;
        energyLabel = View.findDrawableById("Energy") as Toybox.WatchUi.Text;
        stressLabel = View.findDrawableById("Stress") as Toybox.WatchUi.Text;
        pieChart = View.findDrawableById("pieChart") as Toybox.WatchUi.Text;
        displayInfo = [
            dc.getWidth(), dc.getHeight(),
            dc.getWidth() / 2, dc.getHeight() / 2
        ];
        var clockTime = System.getClockTime();
        self.updateData(clockTime, 0);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        self.timer.nextTick();
        if (self.sleepMode == false) {
            self.timer.start();
        }
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        var bufferdc = null as Graphics.Dc?;

        dispatchUpdateButtery();
        dispatchUpdateHeartRate();
        dispatchUpdateSteps();
        dispatchUpdateHeading();
        dispatchUpdateBodyBattery();
        dispatchUpdateStress();

        self.dayNightView.setDayNightInfo(
          self.sunRiseSunSet.sunRise,
          self.sunRiseSunSet.sunSet
        );

        if (self.sleepMode) {
            self.timer.nextTick();
            var clockTime = System.getClockTime();
            self.updateData(clockTime, 0);
        }

        self.buffer = Graphics.createBufferedBitmap({
            :width=>dc.getWidth(),
            :height=>dc.getHeight()
        }).get();

        bufferdc = self.buffer.getDc();

        bufferdc.setAntiAlias(true);

        View.onUpdate(bufferdc);

        drawWeatherIcon(bufferdc, 156, 4, 156, Graphics.COLOR_LT_GRAY);
        drawTemperature(bufferdc, 162, 14, false, Graphics.COLOR_LT_GRAY);
        drawLocation(bufferdc, 70, 140, 260, 260, Graphics.COLOR_LT_GRAY);

        bufferdc.drawBitmap2(55, 35, compassNeedle, {
            :transform => compassAngleTransform
        });
        bufferdc.drawBitmap2(displayInfo[2], displayInfo[3], minuteHand, {
            :transform => minuteHandTransform
        });
        bufferdc.drawBitmap2(displayInfo[2], displayInfo[3], hourHand, {
            :transform => hourHandTransform
        });

        dc.clearClip();
        dc.drawBitmap(0, 0, self.buffer);
        self.onPartialUpdate(dc);
    }

    // Handle the partial update event
    function onPartialUpdate( dc as Dc ) as Void {
      if (self.sleepMode) {
        timer.nextTick();
      }
      self.clearSecondsHand(dc, self.buffer);
      dc.drawBitmap2(0, 0, secondHand, {
          :transform => secondHandTransform
      });
    }

    private var initClip = [[-5.0, 126.0],[-5.0, -1.0],[22.0, -1.0],[22.0, 126.0]];
    function clearSecondsHand(dc as Dc, buffer as BufferedBitmap)
    {
      var clip = secondHandTransform.transformPoints(self.initClip);
      //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      //dc.fillPolygon(clip);
      if (self.previousSeconds < 16.0) {
        dc.setClip(clip[0][0], clip[1][1], clip[2][0] - clip[0][0], clip[3][1] - clip[1][1]);
      } else if (self.previousSeconds < 31.0) {
        dc.setClip(clip[3][0], clip[0][1], clip[1][0] - clip[3][0], clip[2][1] - clip[0][1]);
      } else if (self.previousSeconds < 46.0) {
        dc.setClip(clip[2][0], clip[3][1], clip[0][0] - clip[2][0], clip[1][1] - clip[3][1]);
      } else {
        dc.setClip(clip[1][0], clip[2][1], clip[3][0] - clip[1][0], clip[0][1] - clip[2][1]);
      }
      dc.drawBitmap(0, 0, self.buffer);
    }

    function every5Minutes() as Void {
    }

    var fakeTime = 0;
    var previousSeconds = 0;
    var pid = Controller.create(0.25, 0.03, 0.025);
    var lastStep = 0.0;
    function engineTick(deltaTime) as Void {
        fakeTime += deltaTime / 1000.0;
        self.drawDelay += deltaTime / 1000.0;
        var clockTime = System.getClockTime();

        var seconds = clockTime.sec;
        self.lastStep = self.pid.update(self.lastStep);
        self.pid.setTarget(seconds);
        self.previousSeconds = seconds;
        var secondAngle = (lastStep/ 60.0) * 2.0 * Math.PI;
        secondHandTransform = new Graphics.AffineTransform();
        secondHandTransform.translate(86.0, 130.0);
        secondHandTransform.rotate(secondAngle);
        secondHandTransform.scale(0.6, 0.6);
        secondHandTransform.translate(-7.5, -108.0);

        if (self.sleepMode) {
            return;
        }

        self.updateData(clockTime, secondAngle);

        WatchUi.requestUpdate();
    }

    function updateData(clockTime, secondAngle) as Void {
        var timeTemplate = self.timeTemplate;
        if ((fakeTime * 2.0).toNumber() % 2 == 0) {
            timeTemplate = self.timeAltTemplate;
        }
        var timeString = Lang.format(
            timeTemplate,
            [clockTime.hour, clockTime.min.format("%02d"), clockTime.sec.format("%02d")]
        );
        clockView.setText(timeString);

        var minutes = clockTime.min;
        if (minutes % 5 == 0) {
            every5Minutes();
        }
        var minuteAngle = (minutes / 60.0) * 2.0 * Math.PI;
        minuteHandTransform = new Graphics.AffineTransform();
        minuteHandTransform.translate(-44.0, -0.0);
        minuteHandTransform.scale(0.7, 0.7);
        minuteHandTransform.rotate(minuteAngle + secondAngle / 60.0);
        minuteHandTransform.translate(-8.5, -88.0);

        var hours = clockTime.hour;
        var hourAngle = (hours / 12.0) * 2.0 * Math.PI;
        hourHandTransform = new Graphics.AffineTransform();
        hourHandTransform.translate(-44.0, -0.0);
        hourHandTransform.rotate(hourAngle + minuteAngle / 12.0);
        hourHandTransform.scale(0.7, 0.7);
        hourHandTransform.translate(-10.0, -58.0);

        var state = getState();
        var heartRateValue = state[:heartRate][:heartRate];
        heartRate.setText(heartRateValue);
        var steps = state[:steps][:steps];
        stepsView.setText(steps);
        var bodyBattery = state[:bodyBattery][:bodyBattery];
        energyLabel.setText(bodyBattery);
        var stress = state[:stress][:stress];
        stressLabel.setText(stress);

        if ((fakeTime * 10.0).toNumber() % 5 == 0) {
          fakePieChartValue = fakePieChartValue < 6 ? fakePieChartValue + 1 : 0;
          self.pieChart.setText(fakePieChartValue.toString());
        }

        var heading = state[:heading][:heading];
        var transform = new Graphics.AffineTransform();
        transform.scale(0.20, 0.20);
        transform.rotate(-heading);
        transform.translate(-15.0, -100.0);
        transform.scale(1.0, 0.5);
        compassAngleTransform = transform;

        if (self.lastHour != clockTime.hour) {
            self.lastHour = clockTime.hour;
            self.labelAmPm.setText(
                clockTime.hour >= 12 ? "PM" : "AM"
            );

            var now = Time.now();
            var date = Date.info(now, Time.FORMAT_SHORT);
            currentDay.setText(
                Lang.format("$1$", [date.day])
            );
            currentDayName.setText(
                Lang.format("$1$", [DAYS[date.day_of_week]])
            );
            if (date.day_of_week == Date.DAY_SUNDAY) {
                currentDayName.setColor(0xff5555);
            } else {
                currentDayName.setColor(Graphics.COLOR_DK_GRAY);
            }
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        self.timer.stop();
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        self.sleepMode = false;
        self.timer.nextTick();
        self.timer.start();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        self.sleepMode = true;
        self.timer.stop();
    }
}

function drawWeatherIcon(dc, x, y, x2, fontColor) {
    var weather = Toybox.Weather.getCurrentConditions();
    if (weather == null) {
      return false;
    }
    var cond = weather.condition;
    var sunset, sunrise;

    if (cond != null and cond instanceof Number) {
      var clockTime = System.getClockTime().hour;
      var WeatherFont = Application.loadResource(Rez.Fonts.WeatherFont);

      // gets the correct symbol (sun/moon) depending on actual sun events
        var position =
            Toybox.Weather.getCurrentConditions()
                .observationLocationPosition;  // or
                                               // Activity.Info.currentLocation
                                               // if observation is null?
        var today =
            Toybox.Weather.getCurrentConditions()
                .observationTime;  // or new Time.Moment(Time.now().value()); ?
        if (position != null and today != null) {
          if (Weather.getSunset(position, today) != null) {
            sunset = Time.Gregorian.info(Weather.getSunset(position, today),
                                         Time.FORMAT_SHORT);
            sunset = sunset.hour;
          } else {
            sunset = 18;
          }
          if (Weather.getSunrise(position, today) != null) {
            sunrise = Time.Gregorian.info(Weather.getSunrise(position, today),
                                          Time.FORMAT_SHORT);
            sunrise = sunrise.hour;
          } else {
            sunrise = 6;
          }
        } else {
          sunset = 18;
          sunrise = 6;
        }

      // weather icon test
      // weather.condition = 6;

      dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
      if (cond == 20) {  // Cloudy
        dc.drawText(x2 - 1, y - 1, WeatherFont, "I",
                    Graphics.TEXT_JUSTIFY_RIGHT);  // Cloudy
      } else if (cond == 0 or cond == 5) {         // Clear or Windy
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2 - 2, y - 1, WeatherFont, "f",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Clear Night
        } else {
          dc.drawText(x2, y - 2, WeatherFont, "H",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Clear Day
        }
      } else if (cond == 1 or cond == 23 or cond == 40 or
                 cond == 52) {  // Partly Cloudy or Mostly Clear or fair or thin
                                // clouds
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2 - 1, y - 2, WeatherFont, "g",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Partly Cloudy Night
        } else {
          dc.drawText(x2, y - 2, WeatherFont, "G",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Partly Cloudy Day
        }
      } else if (cond == 2 or cond == 22) {  // Mostly Cloudy or Partly Clear
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2, y, WeatherFont, "h",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Mostly Cloudy Night
        } else {
          dc.drawText(x, y, WeatherFont, "B",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Mostly Cloudy Day
        }
      } else if (cond == 3 or cond == 14 or cond == 15 or cond == 11 or
                 cond == 13 or cond == 24 or cond == 25 or cond == 26 or
                 cond == 27 or
                 cond == 45) {  // Rain or Light Rain or heavy rain or showers
                                // or unkown or chance
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2, y, WeatherFont, "c",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Rain Night
        } else {
          dc.drawText(x, y, WeatherFont, "D",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Rain Day
        }
      } else if (cond == 4 or cond == 10 or cond == 16 or cond == 17 or
                 cond == 34 or cond == 43 or cond == 46 or cond == 48 or
                 cond ==
                     51) {  // Snow or Hail or light or heavy snow or ice or
                            // chance or cloudy chance or flurries or ice snow
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2, y, WeatherFont, "e",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Snow Night
        } else {
          dc.drawText(x, y, WeatherFont, "F",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Snow Day
        }
      } else if (cond == 6 or cond == 12 or cond == 28 or cond == 32 or
                 cond == 36 or cond == 41 or
                 cond == 42) {  // Thunder or scattered or chance or tornado or
                                // squall or hurricane or tropical storm
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2, y, WeatherFont, "b",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Thunder Night
        } else {
          dc.drawText(x, y, WeatherFont, "C",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Thunder Day
        }
      } else if (cond == 7 or cond == 18 or cond == 19 or cond == 21 or
                 cond == 44 or cond == 47 or cond == 49 or
                 cond == 50) {  // Wintry Mix (Snow and Rain) or chance or
                                // cloudy chance or freezing rain or sleet
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2, y, WeatherFont, "d",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Snow+Rain Night
        } else {
          dc.drawText(x, y, WeatherFont, "E",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Snow+Rain Day
        }
      } else if (cond == 8 or cond == 9 or cond == 29 or cond == 30 or
                 cond == 31 or cond == 33 or cond == 35 or cond == 37 or
                 cond == 38 or
                 cond == 39) {  // Fog or Hazy or Mist or Dust or Drizzle or
                                // Smoke or Sand or sandstorm or ash or haze
        if (clockTime >= sunset or clockTime < sunrise) {
          dc.drawText(x2, y, WeatherFont, "a",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Fog Night
        } else {
          dc.drawText(x, y, WeatherFont, "A",
                      Graphics.TEXT_JUSTIFY_RIGHT);  // Fog Day
        }
      }
      return true;
    } else {
      return false;
    }
  }

  function drawTemperature(dc, x, y, showBoolean, fontColor) {
    var TempMetric = System.getDeviceSettings().temperatureUnits;
    var temp = null, units = "", minTemp = null, maxTemp = null;
    var weather = Weather.getCurrentConditions();
    if (weather == null) {
      return;
    }

    if ((weather.lowTemperature != null) and (weather.highTemperature != null)) {
        // and weather.lowTemperature instanceof Number ;  and
        // weather.highTemperature instanceof Number
      minTemp = weather.lowTemperature;
      maxTemp = weather.highTemperature;
    }

    var offset = 0;

    if (showBoolean == false and
        (weather.feelsLikeTemperature !=
         null)) {  // feels like ;  and weather.feelsLikeTemperature instanceof
                   // Number
      if (TempMetric == System.UNIT_METRIC or
          Storage.getValue(16) == true) {  // Celsius
        units = "°C";
        temp = weather.feelsLikeTemperature;
      } else {
        temp = (weather.feelsLikeTemperature * 9 / 5) + 32;
        if (minTemp != null and maxTemp != null) {
          minTemp = (minTemp * 9 / 5) + 32;
          maxTemp = (maxTemp * 9 / 5) + 32;
        }
        // temp = Lang.format("$1$", [temp.format("%d")] );
        units = "°F";
      }
    } else if ((weather.temperature != null)) {
      // real temperature ;  and weather.temperature
      // instanceof Number
      if (TempMetric == System.UNIT_METRIC or
          Storage.getValue(16) == true) {  // Celsius
        units = "°C";
        temp = weather.temperature;
      } else {
        temp = (weather.temperature * 9 / 5) + 32;
        if (minTemp != null and maxTemp != null) {
          minTemp = (minTemp * 9 / 5) + 32;
          maxTemp = (maxTemp * 9 / 5) + 32;
        }
        // temp = Lang.format("$1$", [temp.format("%d")] );
        units = "°F";
      }
    }

    if (temp != null) {  // and temp instanceof Number
      dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
      if ((minTemp != null) and
          (maxTemp != null)) {  //  and minTemp instanceof Number ;  and maxTemp
                                //  instanceof Number
        if (temp <= minTemp) {
          if (fontColor == Graphics.COLOR_WHITE) {  // Dark Theme
            dc.setColor(Graphics.COLOR_BLUE,
                        Graphics.COLOR_TRANSPARENT);  // Light Blue 0x55AAFF
          } else {                                    // Light Theme
            dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
          }
        } else if (temp >= maxTemp) {
          if (fontColor == Graphics.COLOR_WHITE) {              // Dark Theme
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);  // Light Orange
          } else {                                              // Light Theme
            dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
          }
        }
      }

      // correcting a bug introduced by System 7 SDK
      temp = temp.format("%d");

      dc.drawText(x, y + offset, Graphics.FONT_XTINY, temp,
                  Graphics.TEXT_JUSTIFY_LEFT);  // + units
      dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
      dc.drawText(x + dc.getTextWidthInPixels(temp, Graphics.FONT_XTINY),
                  y + offset, Graphics.FONT_XTINY, units,
                  Graphics.TEXT_JUSTIFY_LEFT);
    }
  }

  function drawLocation(dc, x, y, wMax, hMax, fontColor) {
    var cond = Toybox.Weather.getCurrentConditions();

      if (cond != null and cond.observationLocationName != null) {
        var location = cond.observationLocationName;
        if (location.length() > 15 and location.find(",") != null) {
          location = location.substring(0, location.find(","));
        }
        if (location.find("ocation[") != null) {
          location = "null";
        }
        if (location.find("null") != null and location.find(",") != null) {
          var location2 = location.substring(0, location.find(","));
          if (location2.find("null") != null) {
            location2 =
                location.substring(location.find(",") + 2, location.length());
            if (location2.find("null") != null) {
              location2 = "";
            }
          }
          location = location2;
        } else if (location.find("null") != null) {
          location = "";
        }

        if (x * 2 == 260 and Storage.getValue(3) == false) {
          y = y + 6;
        }

        dc.setColor(
            (fontColor == Graphics.COLOR_WHITE ? Graphics.COLOR_LT_GRAY
                                               : Graphics.COLOR_DK_GRAY),
            Graphics.COLOR_TRANSPARENT);
        // dc.fitTextToArea(text, font, width, height, truncate)
        dc.drawText(
            x, y, Graphics.FONT_XTINY,
            dc.fitTextToArea(location, Graphics.FONT_XTINY, wMax, hMax, true),
            Graphics.TEXT_JUSTIFY_CENTER);
        return true;
      } else {  // Dealing with an error when currentConditions exist but
                // location name still returns null
        return false;
      }
  }
