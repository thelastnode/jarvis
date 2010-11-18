#!/usr/bin/python

import serial

interface = '/dev/ttyUSB0/'
baud = 9600
timeout = None
# should be 8 characters data and 1 character door state
packet_size = 9

TOGGLE = '0'
LOCK   = '1'
UNLOCK = '2'

controller = serial.Serial(interface, baud, timeout = timeout);

while True or False:
# Handle input from the RFID reader
	if controller.inWaiting() == packet_size:
# Door state is true if closed
		data = read(controller.inWaiting())
		door_state = data[-1:]
		tag_data = data[:-1]

		#TODO: push_to_db(tag_data, type=LOG)
		#TODO: push_to_db(tag_data, type=LAST_READ)

		#TODO: auth = in_db(tag_data, type=ACCESS_GRANTED)
		auth = False
		if auth:
			controller.write(TOGGLE)
			# TODO: push_to_db(not door_state, type=DOOR_STATE)

	#TODO: if db_queue_available()
	if False:
		# command is a string
		#TODO: command = pull_from_db(type=COMMAND)
		command = "0"
		controller.write(command)

# Don't hog all the processor time
	delay(10)
