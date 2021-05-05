# extract unique serial number from the platform

def serial_number():
    """Extract a unique serial number from the platform the function is executed upon."""
    # try iMX6 first
    #   https://community.nxp.com/thread/332905
    try:
        sn1 = open('/sys/fsl_otp/HW_OCOTP_CFG0').readline().strip()
        sn2 = open('/sys/fsl_otp/HW_OCOTP_CFG1').readline().strip()
        return 'IMX6{:08x}{:08x}'.format(int(sn1,0), int(sn2,0))
    except IOError:
        pass

    # otherwise try NVidia, then Intel Edison paths
    # NOTE: I settled on reading the ethernet MAC because I was unsatisfied with any of these:
    #   https://devtalk.nvidia.com/default/topic/1027966/how-to-read-tx2-modules-serial-number-in-code-/
    #   https://devtalk.nvidia.com/default/topic/1025409/jetson-tk1/how-to-retrieve-boad-serial-number/
    #   https://devtalk.nvidia.com/default/topic/1036930/jetson-tx2/read-hardware-id-of-the-tx2-som/
    # The Intel Edison path is obtained from:
    #   https://communities.intel.com/thread/57093

    _paths = [
        ('NVID','/proc/device-tree/chosen/nvidia,ether-mac'),    # NVidia TX1/TX2/Xavier
        ('NVID','/proc/device-tree/chosen/nvidia,ethernet-mac'), # NVidia Jetson Nano
	('','/factory/serial_number'),                           # Intel Edison
        ('RPIX','/proc/device-tree/serial-number'),              # Raspberry-PI
    ]
    for (t,p) in _paths:
        try:
            sn = open(p).readline().strip()
            return t+''.join([x for x in sn.split(':')])
        except IOError:
            continue

    # got here?  punt, and go through the remaining network interfaces
    try:
        import netifaces as ni
        for iface in ni.interfaces():
            addr = ni.ifaddresses(iface)[ni.AF_LINK][0]['addr']
            if addr.startswith('00:00:00'):
                continue
            return 'XMAC'+''.join([ x for x in addr.split(':')])
    except Exception as e:
        sys.stderr.write(str(e)+'\n')
    raise RuntimeError('unable to obtain serial number from various methods')

# ---------------------------------------------------------------------------
# For command-line testing
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    
    sn = serial_number()
    sys.stdout.write(sn+'\n')