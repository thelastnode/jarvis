#include <Servo.h>

#define TOGGLE '0'
#define LOCK   '1'
#define UNLOCK '2'
#define INVALID '3'
#define STATE_REQ '4'

#define BAUD 9600

#define SERVO_ON_TIME 1000
#define SERVO_RET_TIME 800

#define SERVO_LOCK 9
#define SERVO_UNLOCK 10

#define SERVO_LOCK_ACT 90
#define SERVO_LOCK_HOME 0

#define SERVO_UNLOCK_ACT 0
#define SERVO_UNLOCK_HOME 90

#define NUM_BITS 35
#define BIT_TIMEOUT 50

#define LOCKED_INDICATOR_PIN 11

#define LOCK_TOGGLE_PIN 4

#define ACK_ID "ACK"
#define ACK_PADDING "ACK_"
#define MAN_OPEN_ID "MAN_"

// For reading bits Wiegand style
unsigned long tag_id = 0;
unsigned int bit_count = 0;

// Timeout for reading from the reader
unsigned long time_since_last_bit = 0;

// The command from the server
unsigned char byte_in = 0;

// Current door state
bool door_locked = false;

// Manual door toggling
// Debounce integrator
unsigned char debounce_integ = 0;
// waiting for release
bool wait_for_release = false;

Servo servo_lock;
Servo servo_unlock;

void setup() {
	Serial.begin(BAUD);
	attachInterrupt(0, count_zero, FALLING);
	attachInterrupt(1, count_one, FALLING);

	pinMode(LOCKED_INDICATOR_PIN, OUTPUT);
	digitalWrite(LOCKED_INDICATOR_PIN, LOW);

	pinMode(LOCK_TOGGLE_PIN, INPUT);
}

void loop(){
	// Check for manual lock toggle
	if (button_toggled()) {
		toggle_door();
		send_man_open();
	}

	// Send tag id
	if (bit_count >= NUM_BITS && millis() - time_since_last_bit > BIT_TIMEOUT) {
		Serial.print(tag_id, HEX);
		bit_count = 0;
		tag_id = 0;
	}

	// Interpret received command
	if (Serial.available() > 0) {
		byte_in = Serial.read();
		switch (byte_in) {
			case TOGGLE:
				toggle_door();
				send_ack();
				break;
			case LOCK:
				lock_door();
				send_ack();
				break;
			case UNLOCK:
				unlock_door();
				send_ack();
				break;
			case INVALID:
				blink_invalid();
				send_ack();
				break;
			case STATE_REQ:
				send_ack();
				break;
			default:
				break;
		}
	}
}

void send_ack() {
	Serial.print(ACK_ID);
	Serial.print(ACK_PADDING);
	Serial.print(door_locked + '0', BYTE);
}

void send_man_open() {
	Serial.print(ACK_ID);
	Serial.print(MAN_OPEN_ID);
	Serial.print(door_locked + '0', BYTE);
}

// Debounce the manual lock toggle button and return true if the 
// button was truely pressed
bool button_toggled() {
	// Toggle the door state
	if (digitalRead(LOCK_TOGGLE_PIN)) {
		if (debounce_integ < 10)
		debounce_integ++;
	} else if (debounce_integ > 0)
		debounce_integ--;

	if (debounce_integ == 10 && !wait_for_release) {
		wait_for_release = true;
		return true;
	} else if (debounce_integ == 0 && wait_for_release) {
		wait_for_release = false;
	}
	return false;
}

void count_one() {
	tag_id = (tag_id<<1) + 1;
	bit_count++;
	time_since_last_bit = millis();
}

void count_zero() {
	tag_id = (tag_id<<1);
	bit_count++;
	time_since_last_bit = millis();
}

void toggle_door() {
	if (door_locked) {
		unlock_door();
	}
	else {
		lock_door();
	}
}

void unlock_door() {
	digitalWrite(LOCKED_INDICATOR_PIN, LOW);
	servo_lock.attach(SERVO_LOCK);
	servo_lock.write(SERVO_LOCK_HOME);

	servo_unlock.attach(SERVO_UNLOCK);

	servo_unlock.write(SERVO_UNLOCK_ACT);
	delay(SERVO_ON_TIME);

	servo_unlock.write(SERVO_UNLOCK_HOME);
	delay(SERVO_RET_TIME);

	servo_lock.detach();
	servo_unlock.detach();

	door_locked = false;
}

void lock_door() {
	digitalWrite(LOCKED_INDICATOR_PIN, HIGH);
	servo_unlock.attach(SERVO_UNLOCK);
	servo_unlock.write(SERVO_UNLOCK_HOME);

	servo_lock.attach(SERVO_LOCK);

	servo_lock.write(SERVO_LOCK_ACT);
	delay(SERVO_ON_TIME);

	servo_lock.write(SERVO_LOCK_HOME);
	delay(SERVO_RET_TIME);

	servo_lock.detach();
	servo_unlock.detach();

	door_locked = true;
}

void blink_invalid() {
	for (int x=0; x<5; x++) {
		digitalWrite(LOCKED_INDICATOR_PIN, HIGH);
		delay(100);
		digitalWrite(LOCKED_INDICATOR_PIN, LOW);
		delay(100);
	}
	if (door_locked)
		digitalWrite(LOCKED_INDICATOR_PIN, HIGH);
}
