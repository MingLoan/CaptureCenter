//
//  UIAlertController+Helpers.swift
//  Pods
//
//  Created by Mingloan Chan on 7/19/17.
//
//

import Foundation

class InternalAlertController: UIAlertController {
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
}

extension UIAlertController {
    
    
    /// weakly point to the view which action sheet popover from.
    weak var sourceView: UIView? {
        get {
            return objc_getAssociatedObject(self, "sourceView") as? UIView
        }
        set(newValue) {
            objc_setAssociatedObject(self, "sourceView", newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    /**
     Convenient methods to present alert or action sheets on a given view controller. Dealing with iPhone and iPad differences on action sheets. You can input
     
     - Parameter title                    Optional. The title string for alert or action sheet.
     - Parameter message                  Optional. The message string for alert or action sheet.
     - Parameter preferredStyle           Optional. Default is .Alert. Options: .Alert or .ActionSheet.
     - Parameter actions                  Optional. UIAlertAction Array for alert controller. Default is a 'OK' Action with no handler code.
     - Parameter presentingViewController Required. View Controller to present.
     - Parameter sourceView               Optional. Just for Style .ActionSheet. You can pass UIView, CGRect(NSValue) or UIBarButtonItem, this methods will help to present action sheet "popover-ly" on iPad(Trait Collection = Regular+Regular).
     
     */
    static func presentAlertController(
        title: String? = nil,
        message: String? = nil,
        preferredStyle: UIAlertControllerStyle = .alert,
        actions: [UIAlertAction]? = [UIAlertAction(title: "OK", style: .cancel, handler: nil)],
        presentingViewController: UIViewController?,
        sourceView: AnyObject? = nil) {
        
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                UIAlertController.presentAlertController(title: title, message: message, preferredStyle: preferredStyle, actions: actions, presentingViewController: presentingViewController, sourceView: sourceView)
            }
            return
        }
        
        let fromViewController = presentingViewController ?? findTopMostPresentedViewController()
        guard let viewController = fromViewController else { print("cannot present alert view due to no presenting view controller."); return }
        
        if  preferredStyle == .actionSheet {
            viewController.view.endEditing(true)
        }
        
        let alertController = InternalAlertController(title: title, message: message, preferredStyle: preferredStyle)
        
        if let actions = actions {
            for alertAction in actions {
                alertController.addAction(alertAction)
            }
        }
        
        if preferredStyle == .actionSheet && UIDevice.current.userInterfaceIdiom == .pad {
            if let popoverPresentationController = alertController.popoverPresentationController {
                
                var optionalActualSourceView: UIView?
                
                if let view = sourceView as? UIView,
                    let superview = view.superview {
                    optionalActualSourceView = view.superview
                    popoverPresentationController.sourceRect = superview.convert(view.frame, to: viewController.view)
                }
                else if let barButtonItem = sourceView as? UIBarButtonItem {
                    optionalActualSourceView = barButtonItem.value(forKey: "view") as? UIView
                    
                    if let superview = optionalActualSourceView?.superview,
                        let unwrappedSourceView = optionalActualSourceView {
                        popoverPresentationController.sourceRect = superview.convert(unwrappedSourceView.frame, to: viewController.view)
                    }
                }
                else if let value = sourceView as? NSValue {
                    let rect = value.cgRectValue
                    popoverPresentationController.sourceRect = rect
                }
                
                popoverPresentationController.sourceView = viewController.view
                alertController.sourceView = optionalActualSourceView
            }
        }
        
        alertController.view.tintColor = UIView().tintColor
        viewController.present(alertController, animated: true) {}
    }
    
    /**
     Override methods to make popover action sheet responds to size changes
     
     - Parameter size:         see Apple doc.
     - Parameter coordinator:  see Apple doc.
     
     */
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        if let sourceView = sourceView,
            let superview = sourceView.superview,
            let popoverPresentationController = popoverPresentationController,
            let presentingViewController = presentingViewController {
            coordinator.animate(alongsideTransition: { (context: UIViewControllerTransitionCoordinatorContext) -> Void in
                
            }, completion: { (context: UIViewControllerTransitionCoordinatorContext) -> Void in
                
                popoverPresentationController.sourceRect = superview.convert(sourceView.frame, to:presentingViewController.view)
                
            })
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    static func presentFailureAlert(title: String?, message: String?, fromViewController: UIViewController?) {
        
        if !Thread.isMainThread {
            DispatchQueue.main.async(execute: {
                UIAlertController.presentFailureAlert(title: title, message: message, fromViewController: fromViewController)
            })
        }
        
        let presentingViewController = fromViewController ?? findTopMostPresentedViewController()
        guard let viewController = presentingViewController else { print("cannot present alert view due to no presenting view controller."); return }
        UIAlertController.presentAlertController(
            title: title,
            message: message,
            preferredStyle: .alert,
            actions: [UIAlertAction(title: "OK", style: .cancel, handler: nil)],
            presentingViewController: viewController,
            sourceView: nil)
    }
    
    static func presentServerUnavailableAlert() {
        if !Thread.isMainThread {
            DispatchQueue.main.async(execute: {
                UIAlertController.presentServerUnavailableAlert()
            })
        }
        if let topMostViewController = UIViewController.findTopMostPresentedViewController() {
            UIAlertController.presentFailureAlert(
                title: nil,
                message: "You are not connected. Please check out your internet and try again.",
                fromViewController: topMostViewController)
        }
    }
    
    static func presentInternetUnavailableAlert() {
        if !Thread.isMainThread {
            DispatchQueue.main.async(execute: {
                UIAlertController.presentInternetUnavailableAlert()
            })
        }
        if let topMostViewController = UIViewController.findTopMostPresentedViewController() {
            UIAlertController.presentFailureAlert(
                title: nil,
                message: "No internet connection. Please check out your internet and try again.",
                fromViewController: topMostViewController)
        }
    }
    
    static func presentTryAgainAlert() {
        if !Thread.isMainThread {
            DispatchQueue.main.async(execute: {
                UIAlertController.presentTryAgainAlert()
            })
        }
        if let topMostViewController = UIViewController.findTopMostPresentedViewController() {
            UIAlertController.presentFailureAlert(
                title: nil,
                message: "Please try again.",
                fromViewController: topMostViewController)
        }
    }
    
    
}

extension UIViewController {
    static func findTopMostPresentedViewController() -> UIViewController? {
        
        if var topViewController = UIApplication.shared.keyWindow?.rootViewController {
            while let newTopViewController = topViewController.presentedViewController {
                topViewController = newTopViewController
            }
            return topViewController
        }
        
        return nil
    }
}
