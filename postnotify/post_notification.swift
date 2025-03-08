import Foundation  

let notificationName = NSNotification.Name("com.nato.gSync.newPath")
let notificationCenter = DistributedNotificationCenter.default()  

func main() {  
    if CommandLine.argc < 2 {  
        print("Usage: post_notification <path>")  
        exit(1)  
    }  
    
    let path = CommandLine.arguments[1]  
    let userInfo = ["path": path]  
    notificationCenter.postNotificationName(notificationName, object: nil, userInfo: userInfo, deliverImmediately: true)  
}  

main()  