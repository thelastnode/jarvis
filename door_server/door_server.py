#!/usr/bin/python

import serial, re, os
from time import sleep, localtime, strftime

# change for appropriate database 
import MySQLdb as db

# Database config
DB = {
    'name' : 'jarvis',
    'user' : 'jarvis',
    'password' : '[sddeptf',
    'host' : 'localhost',
    'port' : '3306',

    'log_table' : 'door_control_rfidlogentry',
    'door_state_table' : 'door_control_doorstate',
    'user_profile_table' : 'door_control_userprofile',
    'queue_table' : 'door_control_queueentry',
}

conn = db.connect(host=DB['host'], user=DB['user'],
                  passwd=DB['password'], db=DB['name'])

# Low level config
BAUD = 57600
# Five seconds to read a full frame (minus 3 character header)
TIMEOUT = 5

# Sendable commands
TOGGLE       = '0'
LOCK         = '1'
UNLOCK       = '2'
INVALID      = '3'
REQ_STATE    = '4'

# Frame ids
TAG_ID      = '#T'
STATE_ID    = '#S'
LOCK_ID    = 'LK'
MAN_OPEN_ID = 'MN'
AJAR_ID     = 'AJ'
END_FRAME   = '$'

FRM_DELIM   = ':'

# 10 seconds to ack
STATE_TIMEOUT = 1000
# 30 seconds to respond to a ping
PING_TIMEOUT = 3000

# time delay for server loop in seconds (can be a float)
TIME_DELAY = 0.01
# time delay for waiting for the serial port to come back
PORT_TIME_DELAY = 3

# Frame read return codes
FRAME_NONE = 0
FRAME_RCV = 1
FRAME_TIMEOUT = 2

old_state = None
is_locked = 0
is_open = 0

def main():
    while True:
        try:
            run_serv()
        except:
            print_timestamp()
            print 'CONN connection lost, re-establishing'
            sleep(PORT_TIME_DELAY)

def run_serv():
    # Timeout counters
    full_frame_timeout_count = 0
    ack_timeout_count = 0
    ping_timeout_count = 0

    write_queue = []

    # empty queue 
    while db_queue_items() > 0:
        db_dequeue_command()

    controller = setup_serial_connection(get_open_serial_port())

    while True:
        # Handle incoming frames with a complete frame header
        (frame_read_status, new_write_queue) = handle_incoming_frames(controller)
        [write_queue.append(x) for x in new_write_queue]

        # Handle database queue
        [write_queue.append(x) for x in process_db_queue(controller)]

        # Successfully received an ack. Reset the timeout
        if frame_read_status == FRAME_RCV:
            #PRINT
            print_timestamp()
            print 'STATE received'

            ack_timeout_count = 0

        # Command ack timed out or reading a whole frame timed out
        if frame_read_status == FRAME_TIMEOUT or ack_timeout_count > STATE_TIMEOUT:
            #PRINT
            print_timestamp()
            print 'CONN connection lost'

            # Reset the connection
            controller.close();
            controller = setup_serial_connection(get_open_serial_port)

            # Reset the timeout counters
            ack_timeout_count = 0
            ping_timeout_count = 0
            full_frame_timeout_count = 0


        # Write all the frames in the queue
        if write_queue:
            send_frames(controller, write_queue)
            # If its zero, make it one. If it already started, don't change it
            # The microcontroller should always have the last word
            ack_timeout_count = max(ack_timeout_count, 1)

        # Waiting for ack?
        if ack_timeout_count > 0:
            ack_timeout_count += 1

        # Send a ping if not already waiting for an ack
        if ping_timeout_count > PING_TIMEOUT and not ack_timeout_count > 0:
            #PRINT
            print_timestamp()
            print 'DATA ping sent'

            write_queue.append(REQ_STATE)
            ping_timeout_count = 0

        ping_timeout_count += 1

        # Don't hog all the processor time
        sleep(TIME_DELAY)

def print_timestamp():
    print strftime("[%a, %d %b %Y %H:%M:%S] ", localtime()),

def get_open_serial_port():
    ports = []

    while not ports:
        #PRINT
        print_timestamp()
        print 'CONN searching for connection'

        sleep(PORT_TIME_DELAY)
        ports = [x for x in os.listdir('/dev/') if re.search('ttyUSB\d+', x)]

    #PRINT
    print_timestamp()
    print 'CONN found port at %s'%ports[0]

    return '/dev/%s'%ports[0]

def setup_serial_connection(interface):
    controller = serial.Serial(interface, BAUD, timeout = TIMEOUT);
    full_frame_timeout_count = 0

    while controller.inWaiting() == 0:
        #PRINT
        print_timestamp()
        print 'CONN initializing ping sent'

        # request door state
        controller.write(REQ_STATE)
        sleep(TIME_DELAY)

    #PRINT
    print_timestamp()
    print 'CONN connection established'

    return controller

def process_db_queue(controller):
    write_queue = []
    while db_queue_items() > 0:
        # command is a string
        command = db_dequeue_command()
        write_queue.append(str(command))

    #PRINT
    if write_queue:
        print_timestamp()
        print 'DB dequeued %d commands'%len(write_queue)

    return write_queue

def handle_incoming_frames(controller):
    global is_locked, is_open
    # Handle all waiting frames
    read_status = FRAME_NONE
    write_queue = []
    while controller.inWaiting():

        frame_str = [controller.read()]
        while not frame_str[-1] == END_FRAME:
            char = controller.read()
            # Timeout on whole frame
            if char == '':
                read_status = FRAME_TIMEOUT
                #PRINT
                print_timestamp()
                print 'CONN frame read timed out'
                return (read_status, write_queue)

            frame_str.append(char)

        frame = ''.join(frame_str).split(':')

        # Received an ack
        if frame[0] == STATE_ID:
            #PRINT
            print_timestamp()
            print 'DATA received ack frame'

            # Successfully received response
            read_status = FRAME_RCV
            for i in range(1, len(frame), 2):
                if frame[i] == LOCK_ID:
                    is_locked = frame[i+1] == '1'
                    db_update_door_state(is_locked)

                    #PRINT
                    print_timestamp()
                    print 'AUTH door state updated. is_locked = %s'%str(is_locked)

                if frame[i] == MAN_OPEN_ID:
                    is_locked = frame[i+1] == '0'
                    db_write_log('MANUAL TOGGLE')

                    #PRINT
                    print_timestamp()
                    print 'AUTH door manually toggled. expected is_locked = %s'%str(is_locked)

                if frame[i] == AJAR_ID:
                    if not is_open = frame[i+1] == '1':
                        play_sound('sounds/airlock_hiss.wav')
                    is_open = frame[i+1] == '1':

                    #PRINT
                    print_timestamp()
                    print 'AUTH door opened/closed. is_open = %s'%str(is_open)

        # Received a tag id
        elif frame[0] == TAG_ID:
            #PRINT
            print_timestamp()
            print 'DATA received tag id frame'

            # Successfully read tag data
            tag_data = frame[1]
            db_write_log(tag_data)
            auth = db_has_access(tag_data)
            if auth:
                write_queue.append(TOGGLE)
                if is_locked:
                    play_sound('sounds/access_granted.wav')
                else:
                    play_sound('sounds/goodbye.wav')

                #PRINT
                print_timestamp()
                print 'AUTH authorized tag id %s'%tag_data

            else:
                write_queue.append(INVALID)
                play_sound('sounds/access_denied.wav')

                #PRINT
                print_timestamp()
                print 'AUTH denied tag id %s'%tag_data

    return (read_status, write_queue)

def send_frames(controller, write_queue):

    #PRINT
    print_timestamp()
    print 'DATA sending %d frames'%len(write_queue)

    while write_queue:
        controller.write(write_queue.pop(0))

def play_sound(filename):
    os.system('mplayer -really-quiet %s 2> /dev/null &'%filename)


# Decorator for try/except-ing SQL
def sql(f):
    def wrapped_f(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except db.Error, e:
            print "ERROR %d: %s" % (e.args[0], e.args[1])
            import sys
            sys.exit(1)
    return wrapped_f

@sql
def db_update_door_state(is_locked):
    global old_state
    if is_locked == old_state:
        return
    else:
        old_state = is_locked

    if is_locked:
        bool_str = 'TRUE'
    else:
        bool_str = 'FALSE'

    cursor = conn.cursor()
    cursor.execute('INSERT INTO %s(creation_time, is_locked) '
                   'VALUES(CURRENT_TIMESTAMP(), %s)'
                   % (DB['door_state_table'], bool_str))
    cursor.close()

@sql
def db_write_log(tag):
    cursor = conn.cursor()
    cursor.execute('INSERT INTO %s(creation_time, tag) '
                   'VALUES(CURRENT_TIMESTAMP(), \'%s\')'
                   % (DB['log_table'], tag))
    cursor.close()

@sql
def db_has_access(tag):
    cursor = conn.cursor()
    rows = cursor.execute('SELECT user_id FROM %s '
                          'WHERE rfid_tag=\'%s\' AND has_access=TRUE'
                          % (DB['user_profile_table'], tag))
    cursor.close()

    return rows > 0

@sql
def db_queue_items():
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM %s;' % DB['queue_table'])
    result = cursor.fetchone()
    cursor.close()

    return result[0]

@sql 
def db_dequeue_command():
    cursor = conn.cursor()
    cursor.execute('SELECT id, command FROM %s ORDER BY creation_time ASC LIMIT 1'
                   % DB['queue_table'])
    result = cursor.fetchone()
    cursor.close()

    cursor = conn.cursor()
    cursor.execute('DELETE FROM %s WHERE id=%d'
                  % (DB['queue_table'], result[0]))
    cursor.close()

    return result[1]

if __name__ == '__main__':
    main()
