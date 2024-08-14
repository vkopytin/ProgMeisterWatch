using Toybox.WatchUi as Ui;
using Toybox.Math;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application;

using Toybox.Activity as Activity;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;


class GraphPixelView extends Ui.Drawable {
    // theming
    var gbackground_color = 0x000000;
    var gmain_color = 0xFFFFFF;
    var gsecondary_color = 0xFF0000;
    var garc_color = 0x555555;
    var gbar_color_indi = 0xAAAAAA;
    var gbar_color_back = 0x550000;
    var gbar_color_0 = 0xFFFF00;
    var gbar_color_1 = 0x0000FF;

    hidden var position = 1;
    hidden var position_x, position_y;
    hidden var graph_width, graph_height;
    var centerX = 166;
    var centerY = 36;
    var settings;

    var smallDigitalFont = WatchUi.loadResource(Rez.Fonts.lcdDisplay);
    var dataType = 1;

    function initialize(params) {
    	Drawable.initialize(params);

        self.dataType = params.get(:dataType);
    	position_x = params.get(:locX);
    	position_y = params.get(:locY);
        self.width = params.get(:width);
        self.height = params.get(:height);

    	graph_width = self.width;
    	graph_height = self.height;
    }

	function get_data_type() {
		return self.dataType;
	}

	function get_data_interator(type) {
		if (type==1) {
			if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getHeartRateHistory)) {
		        return Toybox.SensorHistory.getHeartRateHistory({});
		    }
	    } else if (type==2) {
	    	if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory)) {
		        return Toybox.SensorHistory.getElevationHistory({});
		    }
	    } else if (type==3) {
	    	if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getPressureHistory)) {
		        return Toybox.SensorHistory.getPressureHistory({});
		    }
	    } else if (type==4) {
	    	if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getTemperatureHistory)) {
		        return Toybox.SensorHistory.getTemperatureHistory({});
		    }
	    }
	    return null;
	}

	function need_draw() {
		return get_data_type() > 0;
	}

    function parse_data_value(type, value) {
    	if (type==1) {
			return value;
	    } else if (type==2) {
			if (settings.elevationUnits == System.UNIT_METRIC) {
				// Metres (no conversion necessary).
				return value;
			} else {
				// Feet.
				return  value*3.28084;
			}
	    } else if (type==3) {
	    	return value/100.0;
	    } else if (type==4) {
		    if (settings.temperatureUnits == System.UNIT_STATUTE) {
				return (value * (9.0 / 5)) + 32; // Convert to Farenheit: ensure floating point division.
			} else {
				return value;
			}
	    }
		return 0;
    }

    function draw(dc) {
    	if (!need_draw()) {
    		return;
    	}

    	try {
	    	settings = System.getDeviceSettings();

			var primaryColor = position == 0 ? gbar_color_1 : gbar_color_0;

	    	//Calculation
	    	var targetdatatype = get_data_type();
	        var HistoryIter = get_data_interator(targetdatatype);

	        if (HistoryIter == null) {
	        	dc.setColor(gmain_color, Graphics.COLOR_TRANSPARENT);
	        	dc.drawText(position_x, position_y, smallDigitalFont, "--", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
                return;
	        }

	        var HistoryMin = HistoryIter.getMin();
	        var HistoryMax = HistoryIter.getMax();

	        if (HistoryMin == null || HistoryMax == null) {
	        	dc.setColor(gmain_color, Graphics.COLOR_TRANSPARENT);
	        	dc.drawText(position_x, position_y, smallDigitalFont, "--", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
                return;
	        }
	//         else if (HistoryMin.data == null || HistoryMax.data == null) {
	//        	bufferdc.setColor(gmain_color, Graphics.COLOR_TRANSPARENT);
	//        	bufferdc.drawText(position_x, position_y, smallDigitalFont, "--", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
	//        	return;
	//        }

	        var minMaxDiff = (HistoryMax - HistoryMin).toFloat();

	        var xStep = graph_width;
	        var height = graph_height;
	        var HistoryPresent = 0;

			var HistoryNew = 0;
			var lastyStep = 0;
			var step_max = -1;
			var step_min = -1;

			var latest_sample = HistoryIter.next();
			if (latest_sample != null) {
	    		HistoryPresent = latest_sample.data;
	    		if (HistoryPresent != null) {
		    		// draw diagram
					var historyDifPers = (HistoryPresent - HistoryMin)/minMaxDiff;
					var yStep = historyDifPers * height;
					yStep = yStep>height?height:yStep;
					yStep = yStep<0?0:yStep;
					lastyStep = yStep;
				} else {
					lastyStep = null;
				}
	    	}

			dc.setPenWidth(2);
			dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);

			//Build and draw Iteration
			for (var i = 12; i > 0; i--) {
				var sample = arraySumm([
					HistoryIter.next(), HistoryIter.next(), HistoryIter.next(), HistoryIter.next(),
					HistoryIter.next(), HistoryIter.next(), HistoryIter.next(), HistoryIter.next(),
					HistoryIter.next(), HistoryIter.next(), HistoryIter.next(), HistoryIter.next()
				]) / 12.0;

				if (sample != null) {
					HistoryNew = sample;
					if (HistoryNew == HistoryMax) {
						step_max = xStep;
					} else if (HistoryNew == HistoryMin) {
						step_min = xStep;
					}
					if (HistoryNew == null) {
						// ignore
					} else {
						// draw diagram
						var historyDifPers = ((HistoryNew - HistoryMin))/minMaxDiff;
						var yStep = historyDifPers * height;
						yStep = yStep>height?height:yStep;
						yStep = yStep<0?0:yStep;

						if (lastyStep == null) {
							// ignore
						} else {
							// draw diagram
							//dc.drawLine(position_x+(xStep-graph_width/2),
							//			position_y - (lastyStep-graph_height/2),
							//			position_x+(xStep-graph_width/2),
							//			position_y - (yStep-graph_height/2));
							dc.drawRectangle(
								10 + position_x+(xStep-graph_width/2),
								position_y - (yStep-graph_height/2),
								2, 2
							);
						}
						lastyStep = yStep;
					}
				}
				xStep -= 5;
			}

			dc.setColor(gmain_color, Graphics.COLOR_TRANSPARENT);

			if (HistoryPresent == null) {
	        	dc.drawText(position_x,
						position_y + (position==1?(graph_height/2 + 10):(-graph_height/2-16)),
						smallDigitalFont,
						"--",
						Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
	        	return;
	        }
	        var value_label = parse_data_value(targetdatatype, HistoryPresent);
	        var labelll = value_label.format("%d");
			dc.drawText(position_x,
						position_y + (position==1?(graph_height/2 + 10):(-graph_height/2-16)),
						smallDigitalFont,
						labelll,
						Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

			settings = null;
		} catch(ex) {
			// currently unkown, weird bug
			System.println(ex);
			dc.setColor(gmain_color, Graphics.COLOR_TRANSPARENT);
        	dc.drawText(position_x, position_y, smallDigitalFont, "--", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
    }

	function arraySumm(array) {
		var sum = 0;
		for (var i = 0; i < array.size(); i++) {
			if (array[i] == null) {
				array[i] = 0;
			} else {
				array[i] = array[i].data;
			}
			sum += array[i];
		}
		return sum;
	}
}