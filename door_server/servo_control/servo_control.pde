#include <Servo.h>

#define TOGGLE '0'
#define LOCK   '1'
#define UNLOCK '2'
#define INVALID '3'

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

#define MANUAL_TOGGLE_ID "MANUALOPEN"

// For reading bits Wiegand style
unsigned long output = 0;
unsigned int bit_count = 0;

// Timeout for reading from the reader
unsigned long time_since_last_bit = 0;

// The command from the server
unsigned char byte_in = 0;

// Current door state
unsigned char door_locked = 0;

// Manual door toggling
// Debounce integrator
unsigned char debounce_integ = 0;
// waiting for release
unsigned char wait_for_release = 0;

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
	// Toggle the door state
	if (digitalRead(LOCK_TOGGLE_PIN)) {
		if (debounce_integ < 10)
		debounce_integ++;
	} else if (debounce_integ > 0)
		debounce_integ--;

	if (debounce_integ == 10 && !wait_for_release) {
		Serial.print(MANUAL_TOGGLE_ID);
		Serial.print(door_locked+'0', BYTE);

		toggle_door();
		wait_for_release = 1;
	} else if (debounce_integ == 0 && wait_for_release) {
		wait_for_release = 0;
	}
	
	if (bit_count >= NUM_BITS && millis() - time_since_last_bit > BIT_TIMEOUT) {
		// TODO: not hardcode passkeys
		/*
		if (output == 0x890B07D5 || output == 0x890AC115 || output == 0x2242A89F || output == 0x890A6182 || output == 0x890AA27E)
			toggle_door();
		else
			blink_invalid();
		*/
		Serial.print(output, HEX);
		Serial.print(door_locked + '0', BYTE);
		bit_count = 0;
		output = 0;
	}
	// Interpret command
	if (Serial.available() > 0) {
		byte_in = Serial.read();
		switch (byte_in) {
			case TOGGLE:
				toggle_door();
				break;
			case LOCK:
				lock_door();
				break;
			case UNLOCK:
				unlock_door();
				break;
			case INVALID:
				blink_invalid();
				break;
			default:
				break;
		}
	}
}

void count_one() {
	output = (output<<1) + 1;
	bit_count++;
	time_since_last_bit = millis();
}

void count_zero() {
	output = (output<<1);
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

	door_locked = 0;
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

	door_locked = 1;
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
