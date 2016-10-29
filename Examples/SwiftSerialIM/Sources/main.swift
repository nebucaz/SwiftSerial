import Foundation
import SwiftSerial


let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("Need serial port name, e.g. /dev/ttyUSB0 as the first argument.")
    exit(1)
}

print("Connect a null modem serial cable between two machines before you continue to use this program")

let portName = arguments[1]
let serialPort: SerialPort = SerialPort(path: portName)

var myturn = true


func getKeyPress () -> UnicodeScalar {
    let valueRead: Int = Int(getchar())

    guard let charRead = UnicodeScalar(valueRead) else{
        return UnicodeScalar("")!
    }

    return charRead
}

func printToScreenFrom(myself: Bool, characterToPrint: UnicodeScalar){

    if(myturn && !myself){
        myturn = false
        print("\nOther: ", terminator:"")
    } else if (!myturn && myself){
        myturn = true
        print("\nMe: ", terminator:"")
    }

    print(characterToPrint, terminator:"")
}



do {

    print("Attempting to open port: \(portName)")
    try serialPort.openPort()
    print("Serial port \(portName) opened successfully.")
    defer {
        serialPort.closePort()
        print("Port Closed")
    }

    serialPort.setSettings(receiveRate: .baud9600,
                           transmitRate: .baud9600,
                           minimumBytesToRead: 1)

    
    /* These prepares the stdin so we can getchar() without echoing */
    // Set up the control structure
    var settings = termios()

    // Get options structure for stdin
    tcgetattr(STDIN_FILENO, &settings)

    //Turn off ICANON and ECHO
    settings.c_lflag &= ~tcflag_t(ICANON | ECHO)

    tcsetattr(STDIN_FILENO, TCSANOW, &settings)




    //Turn off output buffering if not multiple threads will have problems printing
    setbuf(stdout, nil);


    //Run the serial port reading function in another thread
    var readingThread = pthread_t()

    let pthreadFunc: @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? = {
        observer in
        while true{
            do{
                var readCharacter = try serialPort.readChar()
                printToScreenFrom(myself: false, characterToPrint: readCharacter)
            } catch {
                print("Error: \(error)")
            }
        }  

    }

    pthread_create(&readingThread, nil, pthreadFunc, nil)



    print("\nReady to send and receive messages in realtime!")
    print("\nMe: ", terminator:"")


    while true {
        var enteredKey = getKeyPress()
        printToScreenFrom(myself: true, characterToPrint: enteredKey)
        var _ = try serialPort.writeChar(enteredKey)
    }


} catch PortError.failedToOpen {
    print("Serial port \(portName) failed to open. You might need root permissions.")
} catch {
    print("Error: \(error)")
}

