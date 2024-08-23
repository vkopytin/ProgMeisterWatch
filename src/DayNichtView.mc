using Toybox.WatchUi as Ui;
using Toybox.Math;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application;

using Toybox.Activity as Activity;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;

class DayNightView extends Ui.Drawable {

    private var fontColor = 0xaaffaa;
    private var graphColor = 0x555555;
    private var sunRiseHour = 1.0;
    private var sunSetHour = 2.0;

    private var background = null as Graphics.BitmapResource?;
    private var dayNightImage = null as Graphics.Bitmap?;
    private var lastBuffer = null as Graphics.BufferedBitmap;
    private var dayNightInfo = null as SunRiseSunSetView?;
    private var fillBackground = null as Graphics.BitmapTexture?;
    private var lastDrawTime = 0;

    function setLastBuffer(buffer as Graphics.BufferedBitmap) {
		if (self.lastBuffer != null) {
			self.lastBuffer.getDc().clear();
		}
		self.lastBuffer = buffer;
	}


    function initialize(params) {
    	Drawable.initialize(params);

		self.graphColor = params.get(:graphColor);
		self.fontColor = params.get(:fontColor);

        self.dayNightImage = WatchUi.loadResource(Rez.Drawables.DayNightArt);
        self.background = WatchUi.loadResource(Rez.Drawables.lcdBackground);
        self.fillBackground = new Graphics.BitmapTexture({ :bitmap => self.background });
    }

    function setDayNightInfo(sunRise, sunSet) as Void {
        self.sunRiseHour = sunRise;
        self.sunSetHour = sunSet;
    }

    function draw(dc as Graphics.Dc) {
        var buffer = null as Graphics.BufferedBitmap?;
        var bufferdc = null as Graphics.Dc?;
        var buffer2 = null as Graphics.BufferedBitmap?;
        var bufferdc2 = null as Graphics.Dc?;

        Drawable.draw(dc);

        try {
            var clockTime = System.getClockTime();
            var lastDrawTime = clockTime.hour * 60 + clockTime.min + clockTime.sec / 60.0;
            if (self.lastDrawTime != 0 && lastDrawTime - self.lastDrawTime <= 0.1) {
                return;
            }
            self.lastDrawTime = lastDrawTime;

            buffer = Graphics.createBufferedBitmap({
                :width => self.width,
                :height => self.height,
            }).get();

            bufferdc = buffer.getDc();

            var dayLength = sunSetHour - sunRiseHour;
            if (dayLength == 0.0) {
                dayLength = 24.0;
            }
            var currentTime = clockTime.hour + clockTime.min / 60.0;
            var sunPositionAngle = Math.PI * 1.68 + (currentTime - sunRiseHour) / dayLength * Math.PI;

            var transform = new Graphics.AffineTransform();
            transform.translate(self.width * 0.5, 50.0);
            transform.rotate(sunPositionAngle);
            transform.translate(-0.5 * self.width, -50.0);

            bufferdc.drawBitmap2(0, 0, self.dayNightImage, {
                :transform => transform,
            });

            buffer2 = Graphics.createBufferedBitmap({
                :width => self.width,
                :height => self.height,
            }).get();
            bufferdc2 = buffer2.getDc();

            bufferdc2.setFill(new Graphics.BitmapTexture({ :bitmap => buffer }));
            bufferdc2.fillCircle(self.width * 0.5, self.height, self.height);

            //bufferdc2.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            bufferdc2.setFill(self.fillBackground);
            bufferdc2.fillCircle(self.width * 0.25, 1.2 * self.height, self.width / 4.0);
            bufferdc2.fillCircle(self.width * 0.75, 1.2 * self.height, self.width / 4.0);

            self.setLastBuffer(buffer2);
            bufferdc.clear();
            buffer = null;
            buffer2 = null;
        } catch (ex) {
            System.println(ex);
        } finally {
            dc.drawBitmap(self.locX, self.locY, self.lastBuffer);
        }
    }
}
