#include <Bounce.h>

#define TOGGLE '0'
#define LOCK   '1'
#define UNLOCK '2'
#define INVALID '3'
#define STATE_REQ '4'

#define BAUD 57600

#define NUM_BITS 35
#define BIT_TIMEOUT 100
#define PARTIAL_READ_TIMEOUT 1000

#define MAN_OPEN_PIN 4
#define LOCK_PIN 5
#define AJAR_PIN 6

#define MAN_OPEN_B 0
#define LOCK_B 1
#define AJAR_B 2

// 3 pins to debounce
#define NUM_DEBOUNCE_PINS 3

#define TAG_ID      "#T:"
#define STATE_ID    "#S:"
#define LOCK_ID     "LK:"
#define MAN_OPEN_ID "MN:"
#define AJAR_ID     "AJ:"
#define END_FRAME	"$"

// For reading bits Wiegand style
volatile uint64_t tag_id = 0;
// Number of bits received
volatile uint8_t bit_count = 0;

// Timeout for reading from the reader
volatile uint32_t time_since_last_bit = 0;

// Current door state
bool is_locked = false;
bool is_ajar = false;

char byte_in;

Bounce bouncers[NUM_DEBOUNCE_PINS];

void setup() {
	Serial.begin(BAUD);
	attachInterrupt(0, count_zero, FALLING);
	attachInterrupt(1, count_one, FALLING);

	init_leds();

	pinMode(MAN_OPEN_PIN, INPUT);
	pinMode(LOCK_PIN, INPUT);
	pinMode(AJAR_PIN, INPUT);

	bouncers[MAN_OPEN_B] = Bounce(MAN_OPEN_PIN, 5);
	bouncers[LOCK_B] = Bounce(LOCK_PIN, 5);
	bouncers[AJAR_B] = Bounce(AJAR_PIN, 5);
}

void loop() {
	servo_machine();
	blinky_machine();

	if (!is_blinking()) {
		if (!is_locked)
			pulse_light();
		else
			reset_digital_light();
	}

	// update debouncers
	for (int i = 0; i < NUM_DEBOUNCE_PINS; i++) {
		bouncers[i].update();
	}

	if (bouncers[LOCK_B].read() != is_locked) {
		is_locked = bouncers[LOCK_B].read();
		send_lock();
	}

	if (bouncers[AJAR_B].read() != is_ajar) {
		is_ajar = bouncers[AJAR_B].read();
		send_door();
	}

	// Partial read timeout
	if (bit_count > 0 && bit_count < NUM_BITS && abs(millis() - time_since_last_bit) > PARTIAL_READ_TIMEOUT ) {
		bit_count = 0;
		tag_id = 0;
	}

	// Send tag id
	if (abs(millis() - time_since_last_bit) > BIT_TIMEOUT && bit_count >= NUM_BITS) {
		send_tag();
	}

	// Interpret received commands
	if (!servo_machine_running()) {
		while (Serial.available() > 0) {
			byte_in = Serial.read();
			switch (byte_in) {
				case TOGGLE:
					toggle_door();
					break;
				case LOCK:
					start_lock();
					break;
				case UNLOCK:
					start_unlock();
					break;
				case INVALID:
					start_blinky();
					break;
				case STATE_REQ:
					send_state();
					break;
				default:
					break;
			}
		}

		if (bouncers[MAN_OPEN_B].risingEdge()) {
			toggle_door();
			send_man_open();
		}
	}
}

void send_tag() {
	Serial.print(TAG_ID);
	Serial.print((unsigned long)((tag_id>>32) & 0xFFFFFFFF), HEX);
	Serial.print((unsigned long)( tag_id      & 0xFFFFFFFF), HEX);
	Serial.print(":");
	Serial.print(END_FRAME);
	bit_count = 0;
	tag_id = 0;
}

void send_door() {
	Serial.print(STATE_ID);
	Serial.print(AJAR_ID);
	Serial.print(is_ajar + '0', BYTE);
	Serial.print(":");
	Serial.print(END_FRAME);
}

void send_lock() {
	Serial.print(STATE_ID);
	Serial.print(LOCK_ID);
	Serial.print(is_locked + '0', BYTE);
	Serial.print(":");
	Serial.print(END_FRAME);
}

void send_state() {
	Serial.print(STATE_ID);
	Serial.print(LOCK_ID);
	Serial.print(is_locked + '0', BYTE);
	Serial.print(":");
	Serial.print(AJAR_ID);
	Serial.print(is_ajar + '0', BYTE);
	Serial.print(":");
	Serial.print(END_FRAME);
}

void send_man_open() {
	Serial.print(STATE_ID);
	Serial.print(MAN_OPEN_ID);
	Serial.print(is_locked + '0', BYTE);
	Serial.print(":");
	Serial.print(END_FRAME);
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
	if (is_locked) {
		start_unlock();
	}
	else {
		start_lock();
	}
}
