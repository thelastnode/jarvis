#define LOCKED_INDICATOR_PIN 11
#define BLINKY_COUNT_MAX 11 // this number needs to be odd not even
#define LIGHT_PULSE_MIN 5
#define LIGHT_PULSE_MAX 30
#define LIGHT_PULSE_DELAY_LIM 1024

uint8_t blinky_count = BLINKY_COUNT_MAX + 1;
unsigned long last_blink;

uint8_t light_pulse = LIGHT_PULSE_MIN;
uint8_t light_pulse_inc = 1;
uint16_t light_pulse_delay = 1;

void init_leds() {
	pinMode(LOCKED_INDICATOR_PIN, OUTPUT);
	analogWrite(LOCKED_INDICATOR_PIN, light_pulse);
}

void reset_digital_light() {
	digitalWrite(LOCKED_INDICATOR_PIN, HIGH);
}

void reset_analog_light() {
	light_pulse = LIGHT_PULSE_MIN;
	analogWrite(LOCKED_INDICATOR_PIN, light_pulse);
}

void pulse_light() {
	if (!is_locked) {
		light_pulse_delay++;
		if (light_pulse_delay == LIGHT_PULSE_DELAY_LIM) {
			light_pulse_delay = 0;

			light_pulse += light_pulse_inc;
			analogWrite(LOCKED_INDICATOR_PIN, light_pulse);
			if (light_pulse >= LIGHT_PULSE_MAX)
				light_pulse_inc = -1;
			else if (light_pulse <= LIGHT_PULSE_MIN)
				light_pulse_inc = 1;
		}
	}
}

void start_blinky() {
	blinky_count = 0;
}

bool is_blinking() {
	return blinky_count != BLINKY_COUNT_MAX + 1;
}

void blinky_machine() {
	if (blinky_count <= BLINKY_COUNT_MAX) {
		if (blinky_count == 0) {
			digitalWrite(LOCKED_INDICATOR_PIN, blinky_count);
			blinky_count++;
			last_blink = millis();
		} 
		if (millis() - last_blink >= 100) {
			if (blinky_count < BLINKY_COUNT_MAX) {
				digitalWrite(LOCKED_INDICATOR_PIN, blinky_count%2);
				blinky_count++;
				last_blink = millis();
			} else if (blinky_count == BLINKY_COUNT_MAX) {
				if (is_locked)
					digitalWrite(LOCKED_INDICATOR_PIN, HIGH);
				blinky_count++;
			}
		}
    }
}
