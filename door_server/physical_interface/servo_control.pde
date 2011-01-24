#include <Servo.h>

#define SERVO_ON_TIME 1000
#define SERVO_RET_TIME 800

#define SERVO_LOCK 9
#define SERVO_UNLOCK 10

#define SERVO_LOCK_ACT 90
#define SERVO_LOCK_HOME 0

#define SERVO_UNLOCK_ACT 0
#define SERVO_UNLOCK_HOME 90

Servo servo_lock;
Servo servo_unlock;

enum servo_states {act_l, ret_l, act_u, ret_u, ended, holding};
servo_states servo_at = holding;

unsigned long last_trigger;

bool servo_machine_running() {
	return servo_at != holding;
}

void start_lock() {
	servo_at = act_l;
}

void start_unlock() {
	servo_at = act_u;
}

void servo_machine() {
    switch (servo_at) {
    case act_l:
        servo_unlock.attach(SERVO_UNLOCK);
        servo_unlock.write(SERVO_UNLOCK_HOME);

        servo_lock.attach(SERVO_LOCK);
        servo_lock.write(SERVO_LOCK_ACT);

        servo_at = ret_l;
		last_trigger = millis();
        break;

    case act_u:
        servo_lock.attach(SERVO_LOCK);
        servo_lock.write(SERVO_LOCK_HOME);

        servo_unlock.attach(SERVO_UNLOCK);
        servo_unlock.write(SERVO_UNLOCK_ACT);

        servo_at = ret_u;
		last_trigger = millis();
        break;

    case ret_l:
		if (abs(millis() - last_trigger) >= SERVO_ON_TIME) {
			servo_lock.write(SERVO_LOCK_HOME);
			servo_at = ended;
			last_trigger = millis();
		}
        break;

    case ret_u:
		if (abs(millis() - last_trigger) >= SERVO_ON_TIME) {
			servo_unlock.write(SERVO_UNLOCK_HOME);
			servo_at = ended;
			last_trigger = millis();
		}
        break;

    case ended:
		if (abs(millis() - last_trigger) >= SERVO_RET_TIME) {
			servo_lock.detach();
			servo_unlock.detach();
			servo_at = holding;
		}
        break;
    }
}
