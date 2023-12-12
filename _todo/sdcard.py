import objc
from Foundation import NSBundle, NSURL
from IOKit import IOServiceMatching, IOIteratorNext, kIOMasterPortDefault, kIOServicePlane

# Create a Python interface to the IOKit framework
objc.loadBundle('IOKit', bundle_path=NSBundle.mainBundle().bundlePath)

def find_sd_card_reader():
    # Create a dictionary to match devices with the "AppleSDCardReader" service type
    matching_dict = IOServiceMatching("AppleSDCardReader")

    # Get the I/O Kit master port
    master_port = kIOMasterPortDefault

    # Create an iterator for matching devices
    iterator = IOServiceIterator(IOServiceGetMatchingServices(master_port, matching_dict, None))

    # Find the first matching device
    device = IOIteratorNext(iterator)

    if device:
        # Get the device's BSD name (e.g., /dev/diskX)
        bsd_name = IORegistryEntryCreateCFProperty(device, "BSD Name", None, 0)
        if bsd_name:
            return bsd_name.decode()
    
    return None

# Find the SD card reader and get its /dev/xxx path
sd_card_path = find_sd_card_reader()

if sd_card_path:
    print(f"SD card reader found at {sd_card_path}")
else:
    print("SD card reader not found")
