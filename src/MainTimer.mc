import Toybox.System;
import Toybox.Timer;

class MainTimer {
    static function create(instWithEngineTick) {
        var inst = new MainTimer(instWithEngineTick);

        return inst;
    }

    var timer as Timer.Timer;
    var deltaTime = 100;
    var lastTime = System.getTimer();
    var accumulatedTime = 0;

    var instWithEngineTick;

    function initialize(instWithEngineTick) {
        self.instWithEngineTick = instWithEngineTick;
        self.timer = new Timer.Timer();
    }

    function nextTick() {
        var time = System.getTimer();
        self.accumulatedTime += (time - self.lastTime);

        if (self.accumulatedTime > 1000) {
            self.accumulatedTime = 1000;
        }

        while (self.accumulatedTime > self.deltaTime) {
            self.instWithEngineTick.engineTick(self.deltaTime);
            self.accumulatedTime -= self.deltaTime;
        }

        self.lastTime = time;
    }

    function start() as Void {
        self.enqueue();
    }

    function stop() {

    }

    private function enqueue() as Void {
        self.timer.start(method(:update), 100, false);
    }

    function update() as Void {
        self.nextTick();
        self.enqueue();
    }
}
