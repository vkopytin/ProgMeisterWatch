import Toybox.System;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application.Storage;

class BatteryView extends WatchUi.Drawable {
    var x = 0;
    var y = 0;
    var font = Graphics.FONT_GLANCE;
    var symbols = WatchUi.loadResource(Rez.Fonts.id_symbols);
    var statusIcons = WatchUi.loadResource(Rez.Fonts.system12);
    var fontSize = Graphics.FONT_TINY;
    var fontColor = Graphics.COLOR_WHITE;

    function initialize(params) {
        Drawable.initialize(params);
        self.x = params.get(:locX);
        self.y = params.get(:locY);
        self.fontSize = params.get(:fontSize);
        self.fontColor = params.get(:fontColor);
    }

    function draw(dc as Dc) {
        Drawable.draw(dc);

        var xBattery = x;
        var yBattery = y;

        var state = getState();
        var battery = state[:battery][:level];
        var charging = state[:battery][:charging];
        var isSolarCharging = state[:battery][:isSolarCharging];
        var solarColor = state[:battery][:solarColor];
        var solarStatusIcon = state[:battery][:solarStatusIcon];

        dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xBattery, yBattery, symbols, "d", Graphics.TEXT_JUSTIFY_CENTER);
        dc.fillRectangle(xBattery - 5, yBattery + 10, battery * 0.09, 5);

        if (charging) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xBattery - 6, yBattery + 2, symbols, "E", Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (isSolarCharging) {
            dc.setColor(solarColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xBattery - 24, yBattery + 5, statusIcons, solarStatusIcon, Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(fontColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xBattery - 24, yBattery + 5, statusIcons, solarStatusIcon, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}