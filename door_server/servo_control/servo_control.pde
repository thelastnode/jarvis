#include <Servo.h>

#define TOGGLE '0'
#define LOCK   '1'
#define UNLOCK '2'

// For reading bits Wiegand style
unsigned long output = 0;
unsigned int bit_count = 0;

// Timeout for reading from the reader
unsigned long time_since_last_bit = 0;

// The command from the server
unsigned char byte_in = 0;

// Current door state
unsigned char door_locked = 0;
int servoPos = 10;

Servo servo_lock;
Servo servo_unlock;

void setup() {
	Serial.begin(9600);
	attachInterrupt(0, count_zero, FALLING);
	attachInterrupt(1, count_one, FALLING);
}

void loop(){
	if (bit_count >= 35) {
		if (output == 0x890B07D5 || output == 0x890AC115 || output == 0x2242A89F || output == 0x890A6182)
			toggle_door();
		Serial.print(output, HEX);
		Serial.print(door_locked, BYTE);
		bit_count = 0;
		output = 0;
	}
	if (Serial.available() > 0) {
		byte_in = Serial.read();
		if (byte_in == TOGGLE) {
			toggle_door();
		}
		else if (byte_in == LOCK) {
			lock_door();
		}
		else if (byte_in == UNLOCK) {
			unlock_door();
		}
	}
	if (millis() - time_since_last_bit > 1000) {
		output = 0;
		bit_count = 0;
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

void lock_door() {
		servo_lock.attach(9);
		servo_lock.write(0);

		servo_unlock.attach(10);
		servo_unlock.write(0);
		delay(1000);
		servo_unlock.write(90);
		delay(800);

		servo_lock.detach();
		servo_unlock.detach();
		door_locked = 0;
}

void unlock_door() {
		servo_unlock.attach(10);
		servo_unlock.write(90);

		servo_lock.attach(9);
		servo_lock.write(90);
		delay(1000);
		servo_lock.write(0);
		delay(800);

		servo_lock.detach();
		servo_unlock.detach();
		door_locked = 1;
}