#!/usr/bin/python

from time import sleep

# change for appropriate database 
import MySQLdb as db

import serial

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
interface = '/dev/ttyUSB0'
baud = 9600
timeout = None
# should be 8 characters data and 1 character door state
packet_size = 9

TOGGLE = '0'
LOCK   = '1'
UNLOCK = '2'
INVALID = '3'
REQ_STATE = '4'

manual_toggle_id = 'MANOPEN_'
state_req_id = 'GGGGGGGG'

# time delay for server loop in seconds (can be a float)
TIME_DELAY = 1

controller = serial.Serial(interface, baud, timeout = timeout);

old_state = None

def main():
    # empty queue 
    while db_queue_items() > 0:
        db_dequeue_command()

    while True:
        # Handle input from the RFID reader
        if controller.inWaiting() == packet_size:
            # Door state is true if closed
            data = read(controller.inWaiting())
            door_state = data[-1:]
            tag_data = data[:-1]

            db_update_door_state(door_state)

            if tag_data != manual_toggle_id and tag_data != state_req_id:
                db_write_log(tag_data)

                auth = db_has_access(tag)
                if auth:
                    controller.write(TOGGLE)
                    db_update_door_state(not door_state)
                else:
                    controller.write(INVALID)

        while db_queue_items() > 0:
            # command is a string
            command = db_dequeue_command()
            controller.write(command)

        # Don't hog all the processor time
        sleep(TIME_DELAY)

# Decorator for try/except-ing SQL
def sql(f):
    def wrapped_f(*args, **kwargs):
        try:
            f(*args, **kwargs)
        except db.Error, e:
            print "ERROR %d: %s" % (e.args[0], e.args[1])
            import sys
            sys.exit(1)
    return wrapped_f

@sql
def db_update_door_state(is_locked):
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
    rows = cursor.execute('SELECT user_id FROM %s'
                          'WHERE tag=\'%s\' AND has_access=TRUE'
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
