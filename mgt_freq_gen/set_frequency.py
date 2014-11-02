import serial, sys, math, struct, time, numpy

s = serial.Serial("COM42", 460800)

def setFrequency(freq_hertz):
    parallel_clock = 125.0 * 1000 * 1000
    parallel_bits = 20
    slow_phase_inc = float(freq_hertz) / parallel_clock * math.pow(2, 32)
    fast_phase_inc = slow_phase_inc / parallel_bits
    
    slow_phase_inc_str = struct.pack("<I", round(slow_phase_inc % math.pow(2, 32)))
    fast_phase_inc_str = struct.pack("<I", round(fast_phase_inc % math.pow(2, 32)))
    
    SET = 0x50
    RESET = 0x40
    SLOW = 0x50
    FAST = 0xF0
    RESTART = 0x04
    cmds = ""
    cmds += struct.pack("B", SET | RESTART)
    for i in range(4):
        cmds += struct.pack("B", FAST | i)
        cmds += fast_phase_inc_str[i]
    for i in range(4):
        cmds += struct.pack("B", SLOW | i)
        cmds += slow_phase_inc_str[i]
    cmds += struct.pack("B", RESET | RESTART)
    #print "Sending: " + ", ".join(["%02X" % ord(ch) for ch in cmds])
    s.write(cmds)
    
    #time.sleep(1)
    #cmds = ""
    #cmds += struct.pack("B", RESET | RESTART)
    #print "Sending: " + ", ".join(["%02X" % ord(ch) for ch in cmds])
    #s.write(cmds)
    #s.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print "Usage: set_frequency.py FLOAT_FREQ_IN_HERTZ [MODE:rnd,to] [TO_FREQ] [PAUSE_MS] [STEPS]"
    elif len(sys.argv) == 2:
        setFrequency(float(sys.argv[1]))
    elif sys.argv[2] != "rnd":
        fromF = float(sys.argv[1])
        toF = float(sys.argv[3])
        pause = 0.1 if len(sys.argv) < 5 else float(sys.argv[4]) / 1000
        steps = 20 if len(sys.argv) < 6 else int(sys.argv[5])
        for freq in numpy.linspace(fromF, toF, steps):
            setFrequency(freq)
            time.sleep(pause)
            print "Freq: %f" % freq
    else:
        fromF = float(sys.argv[1])
        toF = float(sys.argv[3])
        pause = 0.1 if len(sys.argv) < 5 else float(sys.argv[4]) / 1000
        while True:
            r = numpy.random.rand()
            freq = fromF + r * (toF - fromF)
            setFrequency(freq)
            time.sleep(pause)
            print "Freq: %f" % freq