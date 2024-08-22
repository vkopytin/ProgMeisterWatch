import Toybox.System;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Position;
import Toybox.System;

class SunRiseSunSetView extends WatchUi.Drawable {
    var font = Graphics.FONT_GLANCE;
    var fontSize = Graphics.FONT_TINY;
    var fontColor = Graphics.COLOR_WHITE;
    var location = [0,0];
    var sunRise = 1.0;
    var sunSet = 2.0;

    var symbols = WatchUi.loadResource(Rez.Fonts.id_symbols);
    var lcdDisplay = WatchUi.loadResource(Rez.Fonts.lcdDisplay9);

    function initialize(params) {
        Drawable.initialize(params);
        self.fontSize = params.get(:fontSize);
        self.fontColor = params.get(:fontColor);

        var wcc = Weather.getCurrentConditions();
        if (wcc != null && wcc.observationLocationPosition != null) {
            var wll = wcc.observationLocationPosition;
            var lat = wll.toDegrees()[0].toFloat();
            var lng = wll.toDegrees()[1].toFloat();
            self.location = [lat, lng];
        } else {
            var pos = Position.getInfo();
            if (pos != null) {
                self.location = pos.position.toDegrees();
            }
        }
    }

    function onPosition(info) {
        self.location = info.position.toDegrees();
    }

    function draw(dc as Dc) {
        Drawable.draw(dc);

        var fieldWidth = self.width;
        var fieldHeight = self.height;
        var iconsColored = true;

        var paddingX = (fieldWidth-50)/2;
        var paddingY = -4;

        sunRise = self.computeSunrise(true)/1000/60/60;
        sunSet = self.computeSunrise(false)/1000/60/60;

        var sunRiseStr = Lang.format("$1$:$2$", [Math.floor(sunRise).format("%02.0f"), Math.floor((sunRise-Math.floor(sunRise))*60).format("%02.0f")]);
        var sunSetStr = Lang.format("$1$:$2$", [Math.floor(sunSet).format("%02.0f"), Math.floor((sunSet-Math.floor(sunSet))*60).format("%02.0f")]);

        // Draw text
        dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
        var textFont = fontSize;
        dc.drawText(locX+fieldWidth-paddingX-dc.getTextWidthInPixels(sunRiseStr, textFont), locY+paddingY+fieldHeight/3+3, textFont, sunRiseStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(locX+fieldWidth-paddingX-dc.getTextWidthInPixels(sunSetStr, textFont), locY+paddingY+fieldHeight/3*2+3, textFont, sunSetStr, Graphics.TEXT_JUSTIFY_LEFT);

        if(iconsColored)
    	{
        	dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        }
        else
        {
        	dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
        }
        //dc.drawText(fieldXY[0]+fieldWidth/2, fieldXY[1]+paddingY, symbols, "y", Graphics.TEXT_JUSTIFY_CENTER); //s, a
        dc.drawText(locX+fieldWidth/2, locY+paddingY, symbols, "|", Graphics.TEXT_JUSTIFY_CENTER); //s, a
        dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(locX+fieldWidth/2, locY+paddingY, symbols, "}", Graphics.TEXT_JUSTIFY_CENTER); //s, a
        dc.drawText(locX+paddingX, locY+paddingY+fieldHeight/3+1, symbols, "z", Graphics.TEXT_JUSTIFY_LEFT); //^, s
        dc.drawText(locX+paddingX, locY+paddingY+fieldHeight/3*2+2, symbols, "{", Graphics.TEXT_JUSTIFY_LEFT); //v, r
    }

    function dayOfTheYear()
    {
        var day = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day;
        var month = Gregorian.info(Time.now(), Time.FORMAT_SHORT).month;
        var year = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year;

        var N1 = Math.floor(275 * month / 9);
        var N2 = Math.floor((month + 9) / 12);
        var N3 = (1 + Math.floor((year - 4 * Math.floor(year / 4) + 2) / 3));
        return N1 - (N2 * N3) + day - 30;
    }

    function computeSunrise(sunrise)
    {
        /*Sunrise/Sunset Algorithm taken from
            http://williams.best.vwh.net/sunrise_sunset_algorithm.htm
            inputs:
                day = day of the year
                sunrise = true for sunrise, false for sunset
            output:
                time of sunrise/sunset in hours */
        var day = dayOfTheYear();
        var latitude = location[0];
        var longitude = location[1];
        var zenith = 90.83333333333333;
        var D2R = Math.PI / 180;
        var R2D = 180 / Math.PI;

        // convert the longitude to hour value and calculate an approximate time
        var lnHour = longitude / 15;
        var t;
        if (sunrise) {
            t = day + ((6 - lnHour) / 24);
        } else {
            t = day + ((18 - lnHour) / 24);
        }

        //calculate the Sun's mean anomaly
        var M = (0.9856 * t) - 3.289;

        //calculate the Sun's true longitude
        var L = M + (1.916 * Math.sin(M * D2R)) + (0.020 * Math.sin(2 * M * D2R)) + 282.634;
        if (L > 360) {
            L = L - 360;
        } else if (L < 0) {
            L = L + 360;
        }

        //calculate the Sun's right ascension
        var RA = R2D * Math.atan(0.91764 * Math.tan(L * D2R));
        if (RA > 360) {
            RA = RA - 360;
        } else if (RA < 0) {
            RA = RA + 360;
        }

        //right ascension value needs to be in the same qua
        var Lquadrant = (Math.floor(L / (90))) * 90;
        var RAquadrant = (Math.floor(RA / 90)) * 90;
        RA = RA + (Lquadrant - RAquadrant);

        //right ascension value needs to be converted into hours
        RA = RA / 15;

        //calculate the Sun's declination
        var sinDec = 0.39782 * Math.sin(L * D2R);
        var cosDec = Math.cos(Math.asin(sinDec));

        //calculate the Sun's local hour angle
        var cosH = (Math.cos(zenith * D2R) - (sinDec * Math.sin(latitude * D2R))) / (cosDec * Math.cos(latitude * D2R));
        var H;
        if (sunrise) {
            H = 360 - R2D * Math.acos(cosH);
        } else {
            H = R2D * Math.acos(cosH);
        }
        H = H / 15;

        //calculate local mean time of rising/setting
        var T = H + RA - (0.06571 * t) - 6.622;

        //adjust back to UTC
        var UT = T - lnHour;
        if (UT > 24) {
            UT = UT - 24;
        } else if (UT < 0) {
            UT = UT + 24;
        }

        //convert UT value to local time zone of latitude/longitude
        var localT = UT + 2;

        //convert to Milliseconds
        return localT * 3600 * 1000;
    }
}