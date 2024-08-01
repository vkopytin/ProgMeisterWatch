import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
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
    static const evenTemplate = "$1$:$2$";
    static const oddTemplate = "$1$ $2$";
    static const RAD_90_DEG = 1.570796;

    private var timer = MainTimer.create(self);
    private var sleepMode = false;
    private var timeView = null as Toybox.WatchUi.Text;
    private var clockView = null as Toybox.WatchUi.Text;
    private var currentDay = null as Toybox.WatchUi.Text;
    private var currentDayName = null as Toybox.WatchUi.Text;

    private var secondHand = null as Graphics.BitmapResource;
    private var minuteHand = null as Graphics.BitmapResource;
    private var hourHand = null as Graphics.BitmapResource;
    private var weatherFont = null as Toybox.WatchUi.FontResource;

    private var secondHandTransform = new Graphics.AffineTransform();
    private var minuteHandTransform = new Graphics.AffineTransform();
    private var hourHaneTransform = new Graphics.AffineTransform();

    private var displayInfo = [130, 130, 260, 260] as Array<Number>;

    private var buffer = null as Graphics.BufferedBitmap;

    function initialize() {
        WatchFace.initialize();
        self.secondHand = WatchUi.loadResource(Rez.Drawables.SecondHand);
        self.hourHand = WatchUi.loadResource(Rez.Drawables.HourHand);
        self.minuteHand = WatchUi.loadResource(Rez.Drawables.MinuteHand);
        self.weatherFont = WatchUi.loadResource(Rez.Fonts.weather);
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        dc.setAntiAlias(true);
        setLayout(Rez.Layouts.WatchFace(dc));
        clockView = View.findDrawableById("TimeLabel") as Toybox.WatchUi.Text;
        timeView = View.findDrawableById("TimeDelta") as Toybox.WatchUi.Text;
        currentDay = View.findDrawableById("CurrentDay") as Toybox.WatchUi.Text;
        currentDayName = View.findDrawableById("CurrentDayName") as Toybox.WatchUi.Text;
        displayInfo = [
            dc.getWidth(), dc.getHeight(),
            dc.getWidth() / 2, dc.getHeight() / 2
        ];
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
        self.buffer = null;
        var bufferdc = null;

        //if (self.sleepMode)
        {
            self.buffer = Graphics.createBufferedBitmap({
                :width=>dc.getWidth(),
                :height=>dc.getHeight()
            }).get();

            bufferdc = self.buffer.getDc();
        //} else {
        //    bufferdc = dc;
        }

        bufferdc.setAntiAlias(true);

        View.onUpdate(bufferdc);
        bufferdc.drawBitmap2(displayInfo[2], displayInfo[3], minuteHand, {
            :transform => minuteHandTransform
        });
        bufferdc.drawBitmap2(displayInfo[2], displayInfo[3], hourHand, {
            :transform => hourHaneTransform
        });

        //if (self.sleepMode)
        {
            dc.clearClip();
            dc.drawBitmap(0, 0, self.buffer);
            self.onPartialUpdate(dc);
        }
    }

    // Handle the partial update event
    function onPartialUpdate( dc as Dc ) as Void {
        timer.nextTick();
        self.clearSecondsHand(dc, self.buffer);
        dc.drawBitmap2(displayInfo[2], displayInfo[3], secondHand, {
            :transform => secondHandTransform
        });
    }

    function clearSecondsHand(dc as Dc, buffer as BufferedBitmap)
    {
        var x = 86; // dc.getWidth()/2;
        var y = 130;

        var dcCurClip = calculateSecondHandClip(previousSeconds, x, y, 70.0);
        dc.setClip(dcCurClip[0], dcCurClip[1], dcCurClip[2], dcCurClip[3]);
        //dc.drawRectangle(dcCurClip[0], dcCurClip[1], dcCurClip[2], dcCurClip[3]);

        dc.drawBitmap(0,0,buffer);
    }

    var fakeTime = 0;
    var previousSeconds = 0;
    var pid = Controller.create(0.2, 0.05, 0.1);
    var lastStep = 0.0;
    function engineTick(deltaTime) as Void {
        fakeTime += deltaTime / 1000.0;
        var clockTime = System.getClockTime();

        var seconds = clockTime.sec;
        self.lastStep = self.pid.update(self.lastStep);
        self.pid.setTarget(seconds);
        self.previousSeconds = seconds;
        var secondAngle = (lastStep/ 60.0) * 2.0 * Math.PI;
        secondHandTransform = new Graphics.AffineTransform();
        secondHandTransform.translate(-44.0, -0.0);
        secondHandTransform.rotate(secondAngle);
        secondHandTransform.scale(0.6, 0.6);
        secondHandTransform.translate(-7.5, -100.0);

        if (self.sleepMode) {
            return;
        }

        var template = clockTime.sec % 2 == 0 ? evenTemplate : oddTemplate;
        var timeString = Lang.format(
            template,
            [clockTime.hour, clockTime.min.format("%02d"), clockTime.sec.format("%02d")]
        );

        clockView.setText(timeString);
        var position = Position.getInfo();
        var heading = position.heading;
        timeView.setText((heading).format("%.2f"));

        var minutes = clockTime.min;
        var minuteAngle = (minutes / 60.0) * 2.0 * Math.PI;
        minuteHandTransform = new Graphics.AffineTransform();
        minuteHandTransform.translate(-44.0, -0.0);
        minuteHandTransform.rotate(minuteAngle + secondAngle / 60.0);
        minuteHandTransform.scale(0.8, 0.8);
        minuteHandTransform.translate(-8.5, -80.0);

        var hours = clockTime.hour;
        var hourAngle = (hours / 12.0) * 2.0 * Math.PI;
        hourHaneTransform = new Graphics.AffineTransform();
        hourHaneTransform.translate(-44.0, -0.0);
        hourHaneTransform.rotate(hourAngle + minuteAngle / 12.0);
        hourHaneTransform.scale(0.6, 0.6);
        hourHaneTransform.translate(-10.0, -75.0);

        var now = Time.now();
        var date = Date.info(now, Time.FORMAT_SHORT);
        currentDay.setText(
            Lang.format("$1$", [date.day])
        );
        currentDayName.setText(
            Lang.format("$1$", [DAYS[date.day_of_week]])
        );

        WatchUi.requestUpdate();
    }

    function calculateSecondHandClip(seconds, middleX, middleY, handLength) {
        var angle = (seconds / 60.0) * Math.PI * 2 - RAD_90_DEG;
        var points = [
            middleX+(Math.cos(angle) * handLength),
            middleY+(Math.sin(angle) * handLength),
            middleX+(Math.cos(angle+Math.PI) * handLength * 0.25),   // add PI to get 180 deg (opposite dir)
            middleY+(Math.sin(angle+Math.PI) * handLength * 0.25)    // add PI to get 180 deg
        ];
        var bbox = [
            (points[0] < points[2] ? points[0] : points[2])-2,
            (points[1] < points[3] ? points[1] : points[3])-2,
            (points[0]-points[2]).abs()+4,
            (points[1]-points[3]).abs()+4
        ];
        points = null;
        // need to adjust the bounding box to handle the tail and the hand centers
        if (bbox[0] > middleX-13) {
            bbox[0] = middleX-13;
            bbox[2] += 13;
        }
        if (bbox[1] > middleY-13) {
            bbox[1] = middleY-13;
            bbox[3] += 13;
        }
        if (bbox[0]+bbox[2] < middleX+13) {
            bbox[2] = middleX+13-bbox[0];
        }
        if (bbox[1]+bbox[3] < middleY+13) {
            bbox[3] = middleY+13-bbox[1];
        }
        return (bbox);
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
