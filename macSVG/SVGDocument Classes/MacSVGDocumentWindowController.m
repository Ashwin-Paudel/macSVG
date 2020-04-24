//
//  MacSVGDocumentWindowController.m
//  macSVG
//
//  Created by Douglas Ward on 7/29/11.
//  Copyright © 2016 ArkPhone LLC. All rights reserved.
//

#import "MacSVGDocumentWindowController.h"
#import "MacSVGDocument.h"

#import "MacSVGPlugin/MacSVGPlugin.h"
#import "SVGDTDData.h"

#import "XMLOutlineController.h"
#import "XMLAttributesTableController.h"
#import "XMLAttributesTableView.h"
#import "SVGWebKitController.h"
#import "SVGElementsTableController.h"
#import "EditorUIFrameController.h"
#import "TextDocumentWindowController.h"
#import "TextDocument.h"
#import "DOMMouseEventsController.h"
#import "SVGXMLDOMSelectionManager.h"
#import "VerticalRulerView.h"
#import "HorizontalRulerView.h"
#import "AnimationTimelineView.h"
#import "MacSVGAppDelegate.h"
#import "SelectedElementsManager.h"
#import "WebServerController.h"
#import "SVGWebView.h"
#import "SVGPathEditor.h"
#import "SVGPolylineEditor.h"
#import "SVGLineEditor.h"
#import "NetworkConnectionManager.h"
#import "NSOutlineView_Extensions.h"
#import "DOMSelectionControlsManager.h"
#import "SVGHelpManager.h"
#import "SVGtoCoreGraphicsConverter.h"
#import "SVGtoVideoConverter.h"
#import "SVGtoImagesConverter.h"
#import "ToolSettingsPopoverViewController.h"

#import <stdio.h>
#import <string.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <arpa/inet.h>
#import <ifaddrs.h>

@implementation MacSVGDocumentWindowController

// ================================================================

- (void)dealloc 
{
    [self.svgWebKitController stopPeriodicTimer];
    
    self.selectedPathMode = NULL;
    self.currentTimeString = NULL;
    self.pluginsArray = NULL;
    self.menuPlugInsArray = NULL;
}

//==================================================================================
//	initWithWindow
//==================================================================================

- (instancetype)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        self.pluginsArray = [[NSMutableArray alloc] init];
        self.menuPlugInsArray = [[NSMutableArray alloc] init];
        self.currentToolMode = toolModeArrowCursor;
        self.currentToolSettingsView = NULL;
        self.selectedPathMode = @"Cubic Curve";     // default
    }
    
    return self;
}

//==================================================================================
//	initWithWindowNibName
//==================================================================================

- (instancetype)initWithWindowNibName:(NSString *)windowNibName owner:(id)owner
{
    //self = [super initWithWindowNibName:windowNibName owner:owner];
    self = [super initWithWindowNibName:windowNibName owner:self];
    if (self)
    {
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
        self.pluginsArray = [[NSMutableArray alloc] init];
        self.menuPlugInsArray = [[NSMutableArray alloc] init];
        self.creatingNewElement = NO;
        self.currentToolSettingsView = NULL;
        self.selectedPathMode = @"Cubic Curve";     // default
    }
    return self;
}

//==================================================================================
//	loadPlugins
//==================================================================================

- (IBAction)loadPlugins:(id)sender
{
    // Load plugins
    MacSVGAppDelegate * macSVGAppDelegate = (MacSVGAppDelegate *)NSApp.delegate;

    NSString * plugInsPath = [NSBundle mainBundle].builtInPlugInsPath;
    
    NSArray * bundlePaths = [NSBundle pathsForResourcesOfType:@"plugin"
            inDirectory:plugInsPath];
    
    //WebKitInterface * webKitInterface = [macSVGAppDelegate webKitInterface];

    // Build array of MacSVGPlugin modules
    for (NSString * pathToPlugin in bundlePaths) 
    {
        NSBundle * bundlePlugin = [NSBundle bundleWithPath:pathToPlugin];

        // instantiate the principal class and call the method
        Class principalClass = bundlePlugin.principalClass;
        
        id principalClassObj = [[principalClass alloc] init];
        
        MacSVGPlugin * macSVGPlugin = principalClassObj;
                
        [self.pluginsArray addObject:macSVGPlugin];

        NSMutableDictionary * elementsDictionary =
                macSVGAppDelegate.svgDtdData.elementsDictionary;
        NSMutableDictionary * elementContentsDictionary =
                macSVGAppDelegate.svgDtdData.elementContentsDictionary;
        NSOutlineView * svgXmlOutlineView = self.xmlOutlineController.xmlOutlineView;
        WebView * svgWebView = self.svgWebKitController.svgWebView;
        
        [macSVGPlugin setMacSVGDocument:self.document
                svgXmlOutlineView:svgXmlOutlineView
                svgWebView:svgWebView
                webKitInterface:macSVGAppDelegate.webKitInterface
                elementsDictionary:elementsDictionary
                elementContentsDictionary:elementContentsDictionary];
        
        if (macSVGPlugin.isMenuPlugIn == YES)
        {
            [self.menuPlugInsArray addObject:macSVGPlugin];
        }
    }

    NSMenu * mainMenu = NSApp.mainMenu;

    NSUInteger plugInsMenuIndex = [mainMenu indexOfItemWithTitle:@"Plug-Ins"];
    NSMenuItem * plugInsMenuItem = [mainMenu itemAtIndex:plugInsMenuIndex];
    NSMenu * plugInsMenu = plugInsMenuItem.submenu;
    [plugInsMenu setAutoenablesItems:NO];
    [plugInsMenu removeAllItems];

    NSString * itemTitle = @"No Plug-Ins Enabled";
    NSMenuItem * pluginMenuItem = [plugInsMenu addItemWithTitle:itemTitle action:NULL keyEquivalent:@""];
    [pluginMenuItem setEnabled:NO];
}


// ================================================================

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    /*
    if ([menuItem action] == @selector(Open:))
    {
        // The delete selection item should be disabled if nothing is selected.
        if ([[self selectedNodes] count] > 0)
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    */
    
    NSLog(@"macSVGDocument validateMenuItem %@", menuItem);
    
    return YES;
}

// ================================================================

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    /*
    if ([menuItem action] == @selector(Open:))
    {
        // The delete selection item should be disabled if nothing is selected.
        if ([[self selectedNodes] count] > 0)
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    */
    return YES;
}

//==================================================================================
//	windowDidResignKey:
//==================================================================================

- (void)windowDidResignKey:(NSNotification *)notification
{
    //NSWindow * aWindow = [notification object];
    //NSLog(@"MacSVGDocumentWindowController - windowDidResignKey %@", aWindow);
}

//==================================================================================
//	windowDidBecomeKey:
//==================================================================================

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    //NSWindow * aWindow = [notification object];
    //NSLog(@"MacSVGDocumentWindowController - windowDidBecomeKey %@", aWindow);


    [self showWebBrowserPreviewURL];
}

//==================================================================================
//	windowDidResignMain
//==================================================================================

- (void)windowDidResignMain:(NSNotification *)notification
{
    // Deactivate menu command targets and actions
    NSWindow * aWindow = notification.object;
    #pragma unused(aWindow)
    
    //NSLog(@"MacSVGDocumentWindowController - windowDidResignMain %@", aWindow);

    NSMenu * mainMenu = NSApp.mainMenu;

    NSUInteger fileMenuIndex = [mainMenu indexOfItemWithTitle:@"File"];
    NSMenuItem * fileMenuItem = [mainMenu itemAtIndex:fileMenuIndex];
    NSMenu * fileMenu = fileMenuItem.submenu;

	NSMenuItem * saveWithNetworkConnectionMenuItem = [fileMenu itemWithTitle:@"Save With Network Connection…"];
    [saveWithNetworkConnectionMenuItem setTarget:NULL];
    [saveWithNetworkConnectionMenuItem setAction:NULL];

    NSUInteger svgMenuIndex = [mainMenu indexOfItemWithTitle:@"SVG"];
    NSMenuItem * svgMenuItem = [mainMenu itemAtIndex:svgMenuIndex];
    NSMenu * svgMenu = svgMenuItem.submenu; 

	NSMenuItem * showSvgXmlTextMenuItem = [svgMenu itemWithTitle:@"Show SVG XML Text"];
    [showSvgXmlTextMenuItem setTarget:NULL];
    [showSvgXmlTextMenuItem setAction:NULL];


    NSUInteger editMenuIndex = [mainMenu indexOfItemWithTitle:@"Edit"];
    NSMenuItem * editMenuItem = [mainMenu itemAtIndex:editMenuIndex];
    NSMenu * editMenu = editMenuItem.submenu;

	NSUInteger findMenuIndex = [editMenu indexOfItemWithTitle:@"Find"];
    NSMenuItem * findMenuItem = [editMenu itemAtIndex:findMenuIndex];
    NSMenu * findMenu = findMenuItem.submenu;

	NSMenuItem * findElementMenuItem = [findMenu itemWithTitle:@"Find…"];
    [findElementMenuItem setTarget:NULL];
    [findElementMenuItem setAction:NULL];

	NSMenuItem * findNextElementMenuItem = [findMenu itemWithTitle:@"Find Next"];
    [findNextElementMenuItem setTarget:NULL];
    [findNextElementMenuItem setAction:NULL];


    NSUInteger plugInsMenuIndex = [mainMenu indexOfItemWithTitle:@"Plug-Ins"];
    NSMenuItem * plugInsMenuItem = [mainMenu itemAtIndex:plugInsMenuIndex];
    NSMenu * plugInsMenu = plugInsMenuItem.submenu;
    [plugInsMenu setAutoenablesItems:NO];
    [plugInsMenu removeAllItems];

    NSString * itemTitle = @"No Plug-Ins Enabled";
    NSMenuItem * newPluginMenuItem = [plugInsMenu addItemWithTitle:itemTitle action:NULL keyEquivalent:@""];
    [newPluginMenuItem setEnabled:NO];

    [self showWebBrowserPreviewURL];
}


//==================================================================================
//	windowDidBecomeMain:
//==================================================================================

- (void)windowDidBecomeMain:(NSNotification *)notification
{
    NSWindow * aWindow = notification.object;
    #pragma unused(aWindow)
    
    //NSLog(@"MacSVGDocumentWindowController - windowDidBecomeMain %@", aWindow);

    // Set the menu command targets and actions
    NSMenu * mainMenu = NSApp.mainMenu;

    NSUInteger fileMenuIndex = [mainMenu indexOfItemWithTitle:@"File"];
    NSMenuItem * fileMenuItem = [mainMenu itemAtIndex:fileMenuIndex];
    NSMenu * fileMenu = fileMenuItem.submenu;

	NSMenuItem * saveWithNetworkConnectionMenuItem = [fileMenu itemWithTitle:@"Save With Network Connection…"];
    saveWithNetworkConnectionMenuItem.target = self;
    saveWithNetworkConnectionMenuItem.action = @selector(saveWithNetworkConnection:);

    NSUInteger svgMenuIndex = [mainMenu indexOfItemWithTitle:@"SVG"];
    NSMenuItem * svgMenuItem = [mainMenu itemAtIndex:svgMenuIndex];
    NSMenu * svgMenu = svgMenuItem.submenu; 

	NSMenuItem * showSvgXmlTextMenuItem = [svgMenu itemWithTitle:@"Show SVG XML Text"];
    showSvgXmlTextMenuItem.target = self;
    showSvgXmlTextMenuItem.action = @selector(showSVGXMLTextDocument:);

	NSMenuItem * zoomInMenuItem = [svgMenu itemWithTitle:@"Zoom In"];
    zoomInMenuItem.target = self;
    zoomInMenuItem.action = @selector(zoomIn:);

	NSMenuItem * zoomOutMenuItem = [svgMenu itemWithTitle:@"Zoom Out"];
    zoomOutMenuItem.target = self;
    zoomOutMenuItem.action = @selector(zoomOut:);

	NSMenuItem * resetZoomMenuItem = [svgMenu itemWithTitle:@"Reset Zoom"];
    resetZoomMenuItem.target = self;
    resetZoomMenuItem.action = @selector(resetZoom:);

    // Edit menu items

    NSUInteger editMenuIndex = [mainMenu indexOfItemWithTitle:@"Edit"];
    NSMenuItem * editMenuItem = [mainMenu itemAtIndex:editMenuIndex];
    NSMenu * editMenu = editMenuItem.submenu;
    [editMenu setAutoenablesItems:NO];

	NSUInteger findMenuIndex = [editMenu indexOfItemWithTitle:@"Find"];
    NSMenuItem * findMenuItem = [editMenu itemAtIndex:findMenuIndex];
    NSMenu * findMenu = findMenuItem.submenu;

	NSMenuItem * findElementMenuItem = [findMenu itemWithTitle:@"Find…"];
    findElementMenuItem.target = self;
    findElementMenuItem.action = @selector(findElement:);

	NSMenuItem * findNextElementMenuItem = [findMenu itemWithTitle:@"Find Next"];
    findNextElementMenuItem.target = self;
    findNextElementMenuItem.action = @selector(findNextElement:);
    
    [self enableEditMenuItems];  // for cut/copy/paste elements

    // Plugins menu items
    
    NSUInteger plugInsMenuIndex = [mainMenu indexOfItemWithTitle:@"Plug-Ins"];
    NSMenuItem * plugInsMenuItem = [mainMenu itemAtIndex:plugInsMenuIndex];
    NSMenu * plugInsMenu = plugInsMenuItem.submenu;
    [plugInsMenu setAutoenablesItems:NO];
    [plugInsMenu removeAllItems];

    if ((self.menuPlugInsArray).count == 0)
    {
        NSString * itemTitle = @"No Plug-Ins Enabled";
        NSMenuItem * newPluginMenuItem = [plugInsMenu addItemWithTitle:itemTitle action:NULL keyEquivalent:@""];
        [newPluginMenuItem setEnabled:NO];
    }
    else
    {
        for (MacSVGPlugin * macSVGPlugin in self.menuPlugInsArray)
        {
            NSString * itemTitle = macSVGPlugin.pluginMenuTitle;
            NSMenuItem * newPluginMenuItem = [plugInsMenu addItemWithTitle:itemTitle
                    action:@selector(beginMenuPlugIn:) keyEquivalent:@""];
            newPluginMenuItem.target = self;
        }
    }
}
//==================================================================================
//	enableEditMenuItems
//==================================================================================

- (void)enableEditMenuItems
{
    NSMenu * mainMenu = NSApp.mainMenu;

    NSUInteger editMenuIndex = [mainMenu indexOfItemWithTitle:@"Edit"];
    NSMenuItem * editMenuItem = [mainMenu itemAtIndex:editMenuIndex];
    NSMenu * editMenu = editMenuItem.submenu;

    NSArray * selectedItems = [self selectedItemsInOutlineView];
    if (selectedItems.count > 0)
    {
        // enable pasteboard functions for selected elements
        NSMenuItem * cutElementMenuItem = [editMenu itemWithTitle:@"Cut"];
        cutElementMenuItem.target = self;
        cutElementMenuItem.action = @selector(cut:);
        cutElementMenuItem.enabled = YES;

        NSMenuItem * copyElementMenuItem = [editMenu itemWithTitle:@"Copy"];
        copyElementMenuItem.target = self;
        copyElementMenuItem.action = @selector(copy:);
        copyElementMenuItem.enabled = YES;
    }
    else
    {
        NSMenuItem * cutElementMenuItem = [editMenu itemWithTitle:@"Cut"];
        [cutElementMenuItem setTarget:NULL];
        [cutElementMenuItem setAction:NULL];
        cutElementMenuItem.enabled = NO;
    
        NSMenuItem * copyElementMenuItem = [editMenu itemWithTitle:@"Copy"];
        [copyElementMenuItem setTarget:NULL];
        [copyElementMenuItem setAction:NULL];
        copyElementMenuItem.enabled = NO;
    }
}

//==================================================================================
//	cut:
//==================================================================================

- (IBAction)cut:(id)sender
{
    MacSVGDocument * macSVGDocument = self.document;
    [macSVGDocument pushUndoRedoDocumentChanges];

    BOOL isKeyWindow = (self.window).keyWindow;
    if (isKeyWindow == YES)
    {
        NSResponder * firstResponder = (self.window).firstResponder;
        
        if ((firstResponder == self.xmlOutlineController.xmlOutlineView) || (firstResponder == self.svgWebKitController.svgWebView))
        {
            [self.window makeFirstResponder:self.xmlOutlineController.xmlOutlineView];
        
            [self copyXMLElements:sender];
            
            [self.xmlOutlineController deleteElementAction:self];
        }
        else
        {
            //NSLog(@"firstResponder = %@", firstResponder);
            
            if ([firstResponder respondsToSelector:@selector(cut:)] == YES)
            {
                id cutResponder = firstResponder;
                
                [cutResponder cut:sender];
            }
        }
    }
    else
    {
    }
}

//==================================================================================
//	copy:
//==================================================================================

- (IBAction)copy:(id)sender
{
    BOOL isKeyWindow = (self.window).keyWindow;
    if (isKeyWindow == YES)
    {
        NSResponder * firstResponder = (self.window).firstResponder;
        
        if ((firstResponder == self.xmlOutlineController.xmlOutlineView) || (firstResponder == self.svgWebKitController.svgWebView))
        {
            [self copyXMLElements:sender];
        }
        else
        {
            //NSLog(@"firstResponder = %@", firstResponder);
            
            if ([firstResponder respondsToSelector:@selector(copy:)] == YES)
            {
                id copyResponder = firstResponder;
                
                [copyResponder copy:sender];
            }
        }
    }
    else
    {
    }
}

//==================================================================================
//	copyXMLElements:
//==================================================================================

- (IBAction)copyXMLElements:(id)sender
{
    // copy NSXMLFidelityElement and NSXMLNode, which not implement the NSPasteboardWriting protocol
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSInteger changeCount = [pasteboard clearContents];
    #pragma unused(changeCount)
    
    NSArray * selectedItems = [self selectedItemsInOutlineView];
    
    NSMutableArray * copyNodesArray = [NSMutableArray array];
    
    for (NSXMLNode * aXMLNode in selectedItems)
    {
        NSXMLNodeKind nodeKind = aXMLNode.kind;
        
        switch (nodeKind)
        {
            case NSXMLInvalidKind:
            {
                break;
            }
            case NSXMLDocumentKind:
            {
                break;
            }
            case NSXMLElementKind:
            {
                NSXMLElement * aXMLElement = (NSXMLElement *)aXMLNode;
                NSString * elementString = [aXMLElement XMLStringWithOptions:NSXMLNodePreserveCDATA];
                [copyNodesArray addObject:elementString];
                break;
            }
            case NSXMLAttributeKind:
            {
                break;
            }
            case NSXMLNamespaceKind:
            {
                break;
            }
            case NSXMLProcessingInstructionKind:
            {
                break;
            }
            case NSXMLCommentKind:
            {
                break;
            }
            case NSXMLTextKind:
            {
                break;
            }
            case NSXMLDTDKind:
            {
                break;
            }
            case NSXMLEntityDeclarationKind:
            {
                break;
            }
            case NSXMLAttributeDeclarationKind:
            {
                break;
            }
            case NSXMLElementDeclarationKind:
            {
                break;
            }
            case NSXMLNotationDeclarationKind:
            {
                break;
            }
        }
    }

    BOOL copyOK = [pasteboard writeObjects:copyNodesArray];
    
    if (copyOK == NO)
    {
        NSLog(@"Pasteboard Copy failed");
    }
}

//==================================================================================
//	paste:
//==================================================================================

- (IBAction)paste:(id)sender
{
    MacSVGDocument * macSVGDocument = self.document;
    [macSVGDocument pushUndoRedoDocumentChanges];

    NSPasteboard * pasteboard = [NSPasteboard generalPasteboard];
    NSArray * classes = @[[NSString class]];
    NSDictionary * options = @{};
    NSArray * copiedItems = [pasteboard readObjectsForClasses:classes options:options];

    if (copiedItems != nil)
    {
        BOOL isKeyWindow = (self.window).keyWindow;
        if (isKeyWindow == YES)
        {
            NSResponder * firstResponder = (self.window).firstResponder;
            
            if ((firstResponder == self.xmlOutlineController.xmlOutlineView) || (firstResponder == self.svgWebKitController.svgWebView))
            {
                NSXMLElement * rootElement = [macSVGDocument.svgXmlDocument rootElement];

                NSMutableArray * xmlElementsArray = [NSMutableArray array];
                
                for (id clipboardObject in copiedItems)
                {
                    if ([clipboardObject isKindOfClass:[NSString class]] == YES)
                    {
                        NSString * domString = (NSString *)clipboardObject;

                        NSError * xmlError = NULL;
                        
                        NSXMLElement * aElement = [[NSXMLElement alloc] initWithXMLString:domString error:&xmlError];
                        
                        if (xmlError.code == 5)
                        {
                            // text possibly contains multiple elements, so enclose it in a group
                            NSString * groupedElementsDOMString = [NSString stringWithFormat:@"<g>%@</g>", domString];
                            
                            aElement = [[NSXMLElement alloc] initWithXMLString:groupedElementsDOMString error:&xmlError];
                            
                            if (xmlError == NULL)
                            {
                                domString = groupedElementsDOMString;
                            }
                        }
                        
                        if (xmlError == NULL)
                        {
                            if (aElement != NULL)
                            {
                                [xmlElementsArray addObject:aElement];
                            }
                        }
                    }
                }
                
                XMLOutlineController * xmlOutlineController = self.xmlOutlineController;
                //XMLOutlineView * xmlOutlineView = xmlOutlineController.xmlOutlineView;

                NSArray * selectedNodes = [xmlOutlineController selectedNodes];
                
                //NSXMLNode * lastSelectedNode = [selectedNodes lastObject];
                
                NSXMLElement * targetNode = NULL;
                
                NSXMLNode * lastSelectedNode = NULL;
                
                NSInteger minNodeDepth = NSIntegerMax;
                
                if (selectedNodes.count == 0)
                {
                    // No node was selected, so use root element
                    selectedNodes = [NSArray arrayWithObject:rootElement];
                }

                for (NSXMLNode * aSelectedNode in selectedNodes)
                {
                    if (aSelectedNode.kind == NSXMLElementKind)
                    {
                        if (targetNode == NULL)
                        {
                            lastSelectedNode = aSelectedNode;
                            
                            if ([self.xmlOutlineController.xmlOutlineView isItemExpanded:targetNode] == YES)
                            {
                                // target node is expanded, insert child nodes within
                                targetNode = (id)aSelectedNode;
                            }
                            else
                            {
                                // target node is not expanded, insert after target node
                                targetNode = (id)aSelectedNode.parent;
                            }
                            if (targetNode == NULL)
                            {
                                targetNode = rootElement;
                            }
                            minNodeDepth = [self nodeDepth:aSelectedNode];
                        }
                        else
                        {
                            NSInteger aNodeDepth = [self nodeDepth:aSelectedNode];
                            if (aNodeDepth <= minNodeDepth)
                            {
                                lastSelectedNode = aSelectedNode;
                                targetNode = (id)aSelectedNode.parent;
                                if (targetNode == NULL)
                                {
                                    targetNode = rootElement;
                                }
                                minNodeDepth = aNodeDepth;
                            }
                        }
                    }
                }
                
                NSUInteger childIndex = 0;
                
                // Determine the parent to insert into and the child index to insert at.
                if (lastSelectedNode.kind == NSXMLElementKind)
                {
                    NSNotificationCenter * notificationCenter = [NSNotificationCenter defaultCenter];
                    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];

                    NSUInteger indexOfDestinationElement = 0;
                    
                    NSMutableArray * existingDestinationChildElements = [NSMutableArray array];
                    for (NSXMLNode * childNode in targetNode.children)
                    {
                        if (childNode.kind == NSXMLElementKind)
                        {
                            [existingDestinationChildElements addObject:childNode];
                        }
                    }

                    if (existingDestinationChildElements.count > 0)
                    {
                        //indexOfDestinationElement = [targetNode.children indexOfObject:lastSelectedNode];
                        indexOfDestinationElement = [targetNode.children indexOfObject:existingDestinationChildElements.lastObject];
                    }
                    
                    if (indexOfDestinationElement == NSNotFound)
                    {
                        childIndex = targetNode.children.count; // insert after last child node
                    }
                    else
                    {
                        // check rules for valid insertion as child elements
                        BOOL insertIntoTargetAsChildElements = NO;  // default to insert after target element
                        if ([self.xmlOutlineController.xmlOutlineView isItemExpanded:targetNode] == YES)
                        {
                            // If target element is expanded and is a valid parent container, insertIntoTargetAsChildElements is YES
                            insertIntoTargetAsChildElements = [self validateProposedParentElement:targetNode forChildren:xmlElementsArray];
                        }
                        
                        if (insertIntoTargetAsChildElements == NO)
                        {
                            // insert after target node
                            targetNode = (NSXMLElement *)targetNode.parent;
                            indexOfDestinationElement = [targetNode.children indexOfObject:lastSelectedNode];
                            childIndex = indexOfDestinationElement + 1;
                        }
                        else
                        {
                            // insert nodes as children into expanded target node
                            //childIndex = indexOfSourceElement;
                            childIndex = 0;
                        }
                    }
                    
                    NSMutableArray * newNodesArray = [NSMutableArray array];
                    
                    for (NSXMLElement * sourceXMLElement in xmlElementsArray)
                    {
                        NSString * tagName = sourceXMLElement.name;
                        
                        NSXMLElement * newNode = [[NSXMLElement alloc] initWithName:tagName];
                        
                        NSMutableArray * pendingIDs = [NSMutableArray array];
                        
                        [macSVGDocument deepCopyElement:sourceXMLElement destinationElement:newNode pendingIDsArray:pendingIDs];

                        [targetNode insertChild:newNode atIndex:childIndex++];
                        
                        [newNodesArray addObject:newNode];
                    }
                    

                    self.svgLoadFinishedObserver = [notificationCenter addObserverForName:@"SVGWebViewMainFrameDidFinishLoad" object:nil
                            queue:mainQueue usingBlock:^(NSNotification *note)
                    {
                        NSNotificationCenter * notificationCenter2 = [NSNotificationCenter defaultCenter];
                        [notificationCenter2 removeObserver:self.svgLoadFinishedObserver];
                        self.svgLoadFinishedObserver = NULL;
                        
                        // Make sure the target is expanded
                        //[xmlOutlineView expandItem:targetNode expandChildren:NO];
                        [self revealElementInXMLOutline:targetNode];
                        
                        // Select new items.
                        [self.svgXMLDOMSelectionManager setSelectedXMLElements:newNodesArray];
                        
                        
                        [self updateXMLOutlineViewSelections];
                    }];

                    [self reloadAllViews];
                }
            }
            else
            {
                if ([firstResponder respondsToSelector:@selector(paste:)] == YES)
                {
                    id genericFirstResponder = firstResponder;
                    [genericFirstResponder paste:self];
                }
                else
                {
                    NSBeep();
                }
            }
        }
    }
}

//==================================================================================
//	validateProposedParentElement:forChildren:
//==================================================================================

- (BOOL)validateProposedParentElement:(NSXMLElement *)targetElement forChildren:(NSArray *)xmlElementsArray
{
    BOOL result = YES;

    BOOL checkDTDRules = self.toolSettingsPopoverViewController.validateElementPlacement;

    CGEventRef event = CGEventCreate(NULL);
    CGEventFlags modifiers = CGEventGetFlags(event);
    CFRelease(event);
    CGEventFlags flags = (kCGEventFlagMaskAlternate);
    
    if ((modifiers & flags) != 0)
    {
        checkDTDRules = NO;
    }
   
    if (checkDTDRules == YES)
    {
        MacSVGAppDelegate * macSVGAppDelegate = (MacSVGAppDelegate *)NSApp.delegate;
        SVGDTDData * svgDtdData = macSVGAppDelegate.svgDtdData;
        NSDictionary * elementContentsDictionary = svgDtdData.elementContentsDictionary;

        NSString * proposedParentTagName = targetElement.name;
        
        for (NSXMLNode * aNode in xmlElementsArray)
        {
            NSString * sourceTagName = aNode.name;
            
            NSDictionary * allowedChildrenDictionary = elementContentsDictionary[proposedParentTagName];
            NSDictionary * childTagDictionary = allowedChildrenDictionary[sourceTagName];
            
            if (childTagDictionary == NULL)
            {
                // matching tag not found in allowedChildrenDictionary, disallow child insertion
                result = NO;
                break;
            }
        }
    }
    return result;
}

//==================================================================================
//	nodeDepth
//==================================================================================

- (NSInteger)nodeDepth:(NSXMLNode *)aNode
{
    NSInteger nodeDepth = 0;

    NSXMLNode * nextParent = aNode.parent;
    
    while (nextParent != NULL)
    {
        nodeDepth++;
        
        nextParent = nextParent.parent;
    }
    
    return nodeDepth;
}

//==================================================================================
//	selectedElementsArray
//==================================================================================

- (NSMutableArray *)selectedElementsArray
{
    return self.svgXMLDOMSelectionManager.selectedElementsManager.selectedElementsArray;
}

//==================================================================================
//	beginMenuPlugIn:
//==================================================================================

- (IBAction)beginMenuPlugIn:(id)caller
{
    NSMenu * mainMenu = NSApp.mainMenu;
    NSUInteger plugInsMenuIndex = [mainMenu indexOfItemWithTitle:@"Plug-Ins"];
    NSMenuItem * plugInsMenuItem = [mainMenu itemAtIndex:plugInsMenuIndex];
    NSMenu * plugInsMenu = plugInsMenuItem.submenu;
    
    NSInteger plugInIndex = [plugInsMenu indexOfItem:caller];
    
    MacSVGPlugin * macSVGPlugin = (self.menuPlugInsArray)[plugInIndex];
    
    NSString * plugInTitle = macSVGPlugin.pluginMenuTitle;
    #pragma unused(plugInTitle)
    
    BOOL result = [macSVGPlugin beginMenuPlugIn];
    #pragma unused(result)
}

//==================================================================================
//	saveWithNetworkConnection
//==================================================================================

- (IBAction)saveWithNetworkConnection:(id)sender
{
    MacSVGAppDelegate * macSVGAppDelegate = (MacSVGAppDelegate *)NSApp.delegate;
    NetworkConnectionManager * networkConnectionManager =
            [macSVGAppDelegate networkConnectionManager];
    
    MacSVGDocument * macSVGDocument = self.document;
    
    BOOL result = [networkConnectionManager saveAsDocument:macSVGDocument
        networkConnectionDictionary:macSVGDocument.networkConnectionDictionary];
    
    if (result == NO)
    {
        // alert was handled by networkConnectionManager
    }
}

//==================================================================================
//	showSVGXMLTextDocument
//==================================================================================

- (IBAction)showSVGXMLTextDocument:(id)sender
{
    TextDocument * textDocument = [TextDocument new];
    [textDocument makeWindowControllers];
    [[NSDocumentController sharedDocumentController] addDocument: textDocument];
    [textDocument showWindows];
    
	if (textDocument == NULL)
	{
		NSLog(@"showSVGXMLTextDocument failed");
	}
    else
    {
        MacSVGDocument * macSVGDocument = self.document;
        
        NSUInteger xmlOptions =   NSXMLNodePrettyPrint | NSXMLNodePreserveCDATA;
        
        NSString * xmlString = [macSVGDocument filteredSvgXmlDocumentStringWithOptions:xmlOptions];

        if (xmlString != NULL)
        {
            TextDocumentWindowController * aTextDocumentWindowController =
                    textDocument.textDocumentWindowController;
            
            NSTextView * documentTextView = aTextDocumentWindowController.documentTextView;
            
            documentTextView.string = xmlString;
            
            [textDocument showWindows];
        }
        else
        {
            NSBeep();
        }
    }
}

//==================================================================================
// updateRulers
//==================================================================================

- (void)updateRulers
{
    [self.svgWebKitController reloadRulerViews];

    [self.horizontalRulerView setNeedsDisplay:YES];
    [self.verticalRulerView setNeedsDisplay:YES];
}

//==================================================================================
// showSVGElementsPanel
//==================================================================================

- (void)showSVGElementsPanel
{
    [toolsAndElementsView addSubview:svgElementsPanel];
    [svgToolsPanel removeFromSuperview];
    
    NSRect containerFrame = toolsAndElementsView.frame;
    
    svgElementsPanel.frame = containerFrame;
}

//==================================================================================
// showSettingsForCurrentToolMode
//==================================================================================

- (void)showSettingsForCurrentToolMode
{
    NSString * elementName = @"";
    NSString * editorContext = @"tool";

    switch (self.currentToolMode)
    {
        case toolModeNone:
        {
            elementName = @"";
            break;
        }
        case toolModeArrowCursor:
        {
            elementName = @"";
            break;
        }
        case toolModeCrosshairCursor:
        {
            elementName = @"";
            break;
        }
        case toolModeRect:
        {
            elementName = @"rect";
            break;
        }
        case toolModeCircle:
        {
            elementName = @"circle";
            break;
        }
        case toolModeEllipse:
        {
            elementName = @"ellipse";
            break;
        }
        case toolModeText:
        {
            elementName = @"text";
            break;
        }
        case toolModeImage:
        {
            elementName = @"image";
            break;
        }
        case toolModeLine:
        {
            elementName = @"line";
            break;
        }
        case toolModePolyline:
        {
            elementName = @"polyline";
            break;
        }
        case toolModePolygon:
        {
            elementName = @"polygon";
            break;
        }
        case toolModePath:
        {
            elementName = @"path";
            break;
        }
        case toolModePlugin:
        {
            elementName = @"plugin";
            break;
        }
    }

    NSXMLElement * selectedElement = NULL;
    
    NSInteger selectedElementCount = [self.svgXMLDOMSelectionManager.selectedElementsManager selectedElementsCount];
    if (selectedElementCount > 0)
    {
        selectedElement = [self.svgXMLDOMSelectionManager.selectedElementsManager xmlElementAtIndex:0];
    }
    
    if (elementName.length == 0)
    {
        if (selectedElement != NULL)
        {
            elementName = selectedElement.name;
        }
    }

    [self.editorUIFrameController
            setValidEditorsForXMLNode:selectedElement
            elementName:elementName
            attributeName:NULL context:editorContext];
}

//==================================================================================
// resetToolsPanel
//==================================================================================

- (void)resetToolsPanel
{
    // select the arrow tool
    switch (self.currentToolMode)
    {
        case toolModePolyline:
        case toolModePolygon:
            [self endPolylineDrawing];
            break;

        case toolModePath:
            [self endPathDrawing];
            break;

        default:
            break;
    }

    for (NSButton * aButton in toolButtonsArray)
    {
        if (aButton == arrowToolButton)
        {
            NSUInteger objectIndex = [toolButtonsArray indexOfObject:aButton];
            self.currentToolMode = objectIndex;
            aButton.state = NSOnState;            
        }
        else
        {
            aButton.state = NSOffState;            
        }
    }
    (self.svgWebKitController.domMouseEventsController).mouseMode = MOUSE_DISENGAGED;

    [self showSettingsForCurrentToolMode];
}

//==================================================================================
// showToolsPanel
//==================================================================================

- (void)showToolsPanel
{
    [toolsAndElementsView addSubview:svgToolsPanel];
    [svgElementsPanel removeFromSuperview];
    
    NSRect containerFrame = toolsAndElementsView.frame;
    NSRect panelFrame = svgToolsPanel.frame;
    
    NSRect newPanelFrame = panelFrame;
    newPanelFrame.size.width = containerFrame.size.width;
    svgToolsPanel.frame = newPanelFrame;
    
    [self showSettingsForCurrentToolMode];
}

//==================================================================================
// svgElementsButtonClicked
//==================================================================================

- (IBAction)svgElementsButtonClicked:(id)sender
{
    [svgElementsButton setState:YES];
    [svgToolsButton setState:NO];
    [self showSVGElementsPanel];
    [self resetToolsPanel];
}

//==================================================================================
// svgToolsButtonClicked
//==================================================================================

- (IBAction)svgToolsButtonClicked:(id)sender
{
    [svgToolsButton setState:YES];
    [svgElementsButton setState:NO];
    [self showToolsPanel];
    [self resetToolsPanel];
}

//==================================================================================
//	windowDidLoad
//==================================================================================

- (void)windowDidLoad
{
    [super windowDidLoad];
 
    [self loadPlugins:self];
   
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.xmlOutlineController setColumnHeaders];
    
    NSRect dummyButtonRect = NSMakeRect(0, 0, 0, 0);
    NSButton * dummyButton = [[NSButton alloc] initWithFrame:dummyButtonRect];
    
    // order of array items should correspond to toolMode defines in header
    toolButtonsArray = @[dummyButton,    // dummy entry for item 0
            arrowToolButton,
            rectToolButton,
            circleToolButton,
            ellipseToolButton,
            crosshairToolButton,
            polylineToolButton,
            polygonToolButton,
            lineToolButton,
            pluginToolButton,
            textToolButton,
            imageToolButton,
            pathToolButton];
    
    [self updateRulers];
    
    [self.svgElementsTableController loadElementsData];
    
    [self showToolsPanel];
    
    // 1366x768 Macbook Air screen size, menu bar height is 22, so 1344 is minimum height

    [fullWindowTopBottomSplitView adjustSubviews];  // full window top/bottom
    [leftMiddleRightSplitView adjustSubviews];      // elements(left)/webview(middle)/attributes(right)
    [timelineLeftRightSplitView adjustSubviews];    // timeline left/right
    [elementsTopBottomSplitView adjustSubviews];    // elements top/bottom
    [attributesTopBottomSplitView adjustSubviews];  // attributes top/bottom
    
    [self resizeToolButtons];

    //[elementsTopBottomSplitView setPosition:252 ofDividerAtIndex:0];
    
    //[self.editorUIFrameController setValidAttributesView];
    [self.editorUIFrameController setEmptyView];
    
    [self.xmlAttributesTableController unsetXmlElementForAttributesTable];
    
    [self reloadAllViews];
        
    MacSVGDocument * macSVGDocument = self.document;
    NSInteger elementCount = [macSVGDocument countAllXMLElements];
    if (elementCount <= 100)
    {
        [self.xmlOutlineController expandAllNodes];
    }
    
    BOOL enableHTTPServer = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableHTTPServer"];
    if (enableHTTPServer == YES)
    {
    
    }
    
    [self showWebBrowserPreviewURL];

    [fullWindowTopBottomSplitView adjustSubviews];    // full window top/bottom
    [leftMiddleRightSplitView adjustSubviews];        // elements(left)/webview(middle)/attributes(right)
    [elementsTopBottomSplitView adjustSubviews];      // top/bottom
    [attributesTopBottomSplitView adjustSubviews];    // top/bottom
    [timelineLeftRightSplitView adjustSubviews];      // left/right

    NSNotificationCenter * aNotificationCenter = [NSNotificationCenter defaultCenter]; 
        
    [aNotificationCenter addObserver:self selector:@selector(windowResized:)
            name:NSWindowDidResizeNotification object:self.window];

    [self.window makeKeyWindow];
    [self.window makeMainWindow];
}

// ================================================================

- (void)windowResized:(id)sender
{
    [fullWindowTopBottomSplitView adjustSubviews];    // full window top/bottom
    [leftMiddleRightSplitView adjustSubviews];        // elements(left)/webview(middle)/attributes(right)
    [elementsTopBottomSplitView adjustSubviews];      // top/bottom
    [attributesTopBottomSplitView adjustSubviews];    // top/bottom
    [timelineLeftRightSplitView adjustSubviews];      // left/right
}

// ================================================================

- (void)awakeFromNib 
{
    [super awakeFromNib];
    
    // Register to get our custom type, strings, and filenames. Try dragging each into the view!
    [self.xmlOutlineController registerDragTypes];
    
    NSURL * requestURL = [NSURL URLWithString:@"https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/Mona_Lisa%2C_by_Leonardo_da_Vinci%2C_from_C2RMF_retouched.jpg/161px-Mona_Lisa%2C_by_Leonardo_da_Vinci%2C_from_C2RMF_retouched.jpg"];
    NSString * pathExtension = requestURL.pathExtension;
    NSString * mimeType = @"image/jpeg";
    NSString * imageReferenceOptionString = @"Link to Image";
    NSImage * previewImage = [NSImage imageNamed:@"Mona_Lisa,_by_Leonardo_da_Vinci,_from_C2RMF_retouched.jpg"];
    NSNumber * jpegCompressionNumber = @0.5f;
    
    NSMutableDictionary * newImageDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            requestURL, @"url",
            pathExtension, @"pathExtension",
            mimeType, @"MIMEType",
            imageReferenceOptionString, @"imageReferenceOption",
            previewImage, @"previewImage",
            jpegCompressionNumber, @"jpegCompressionNumber",
            //previewData, @"previewData",
            //encodedImageDataString, @"encodedImageDataString",
            nil];
            
    self.imageDictionary = newImageDictionary;
    
    [self setDefaultToolSettings];
}

//==================================================================================
//	setAttributesForXMLNode:
//==================================================================================

- (void)setAttributesForXMLNode:(NSXMLNode *)newSelectedNode
{
    if (newSelectedNode != NULL)
    {
        if (newSelectedNode.kind == NSXMLElementKind)
        {
            // get attributes, populate attributes table view
            NSXMLElement * aElement = (NSXMLElement *)newSelectedNode;
            [self.xmlAttributesTableController setXmlElementForAttributesTable:aElement];
        }
        else
        {
            // clear attributes from attributes table view
            [self.xmlAttributesTableController unsetXmlElementForAttributesTable];
        }
    }
    else
    {
        [self.xmlAttributesTableController unsetXmlElementForAttributesTable];
    }
}

//==================================================================================
//	expandElementInOutline
//==================================================================================

- (void) expandElementInOutline:(NSXMLElement *)aElement
{
    [self.xmlOutlineController expandElementInOutline:aElement];
}

//==================================================================================
//	reloadAllViews
//==================================================================================

- (void)reloadAllViews
{
    [self.xmlOutlineController reloadView];
    [self.xmlAttributesTableController reloadView];
    [self.svgWebKitController reloadView];
    [self.animationTimelineView reloadData];
}

// ================================================================

- (void)reloadWebView
{
    [self.svgWebKitController reloadView];
    [self.xmlAttributesTableController reloadView];
    [self.animationTimelineView reloadData];
}

// ================================================================

- (void)reloadData 
{
    [self.xmlOutlineController reloadData];
    [self.xmlAttributesTableController reloadData];
    [self.animationTimelineView reloadData];
}

// ================================================================

- (void) reloadAttributesTableData;
{
    ////NSIndexSet * xmlAttributesSelectedRowIndexes = self.xmlAttributesTableController.xmlAttributesTableView.selectedRowIndexes;
    
    //NSString * selectedAttributeName = [self.xmlAttributesTableController selectedAttributeName];

    [self.xmlAttributesTableController buildAttributesTableForElement];
    
    ////[self.xmlAttributesTableController.xmlAttributesTableView selectRowIndexes:xmlAttributesSelectedRowIndexes byExtendingSelection:NO];
    
    //[self.xmlAttributesTableController selectAttributeWithName:selectedAttributeName];
}

// ================================================================

- (void)updateSelections
{
    [self reloadAttributesTableData];
    
    [self.svgWebKitController updateSelections];
    
    //[self enableEditMenuItems];
    
    [self performSelector:@selector(enableEditMenuItems) withObject:NULL afterDelay:0.1f];
}

// ================================================================

- (void) updateXMLOutlineViewSelections
{
    [self.xmlOutlineController setSelectedXMLDOMElements:
            self.svgXMLDOMSelectionManager.selectedElementsManager.selectedElementsArray];

    [self enableEditMenuItems];
}

// ================================================================

- (void) revealElementInXMLOutline:(NSXMLElement *)aElement
{
    NSXMLElement * parentElement = aElement;
    
    while (parentElement != NULL)
    {
        [self.xmlOutlineController.xmlOutlineView expandItem:parentElement];
        
        parentElement = (NSXMLElement *)parentElement.parent;
    }
}

// ================================================================

- (void) updateXMLTextContent:(NSString *)textContent macsvgid:(NSString *)macsvgid
{
    MacSVGDocument * macSVGDocument = self.document;
    [macSVGDocument updateXMLTextContent:(NSString *)textContent macsvgid:macsvgid];
}

// ================================================================

- (void)windowWillClose:(NSNotification *)notification
{
    [self.svgWebKitController willCloseSVGWebView];
}

// ================================================================

- (NSArray *)selectedItemsInOutlineView
{
    NSArray * selectedItems = [self.xmlOutlineController selectedItems];
    return selectedItems;
}

// ================================================================

- (void) userChangedElement:(NSXMLElement *)aElement attributes:(NSMutableArray *)xmlAttributesArray
{
    // pause animations temporarily to apply change
    
    //id parentElement = [aElement parent];
    
    MacSVGAppDelegate * macSVGAppDelegate = (MacSVGAppDelegate *)NSApp.delegate;
    WebKitInterface * webKitInterface = [macSVGAppDelegate webKitInterface];
    
    BOOL animationsPaused = YES;

    DOMDocument * domDocument = (self.svgWebKitController.svgWebView).mainFrame.DOMDocument;
    
    DOMNodeList * svgElementsList = [domDocument getElementsByTagNameNS:svgNamespace localName:@"svg"];
    
    DOMElement * svgElement = NULL;
    
    if (svgElementsList.length > 0)
    {
        DOMNode * svgElementNode = [svgElementsList item:0];
        
        svgElement = (DOMElement *)svgElementNode;

        animationsPaused = [webKitInterface animationsPausedForSvgElement:svgElement];

        if (animationsPaused == NO)
        {
            [webKitInterface pauseAnimationsForSvgElement:svgElement];
        }
    }
    

    NSMutableDictionary * newAttributesDictionary = [NSMutableDictionary dictionary];
    
    for (NSDictionary * attributeDictionary in xmlAttributesArray)
    {
        NSString * name = attributeDictionary[@"name"];
        NSString * value = attributeDictionary[@"value"];

        newAttributesDictionary[name] = value;
    }
    
    MacSVGDocument * macSVGDocument = self.document;
    [macSVGDocument setAttributes:newAttributesDictionary forElement:aElement];
    
    [self.svgWebKitController updateElementAttributes:aElement];
    
    NSString * elementName = aElement.name;
    
    BOOL animationElementChanged = NO;
    
    if ([elementName isEqualToString:@"set"] == YES)
    {
        animationElementChanged = YES;
    }
    else if ([elementName isEqualToString:@"animate"] == YES)
    {
        animationElementChanged = YES;
    }
    else if ([elementName isEqualToString:@"animateMotion"] == YES)
    {
        animationElementChanged = YES;
    }
    else if ([elementName isEqualToString:@"animateColor"] == YES)
    {
        animationElementChanged = YES;
    }
    else if ([elementName isEqualToString:@"animateTransform"] == YES)
    {
        animationElementChanged = YES;
    }
    
    if (animationElementChanged == YES)
    {
        [self.animationTimelineView reloadData];
    }

    if (animationsPaused == NO)
    {
        [webKitInterface unpauseAnimationsForSvgElement:svgElement];
    }
    
    //[[self document] updateChangeCount:(NSChangeDone | NSChangeDiscardable)];       // 20160810
    [self.document updateChangeCount:NSChangeDone];       // 20160919
}

// ================================================================

- (void)endPolylineDrawing
{
    [self.svgWebKitController.domMouseEventsController endPolylineDrawing];
}

// ================================================================

- (void)endLineDrawing
{
    [self.svgWebKitController.domMouseEventsController endLineDrawing];
}

// ================================================================

- (void)endPathDrawing
{
    [self.svgWebKitController.domMouseEventsController endPathDrawing];
}

// ================================================================

- (void)endCrosshairCursorEditing
{
    [self.svgWebKitController.domMouseEventsController.svgPathEditor removePathHandles];
    [self.svgWebKitController.domMouseEventsController.svgPolylineEditor removePolylineHandles];
    [self.svgWebKitController.domMouseEventsController.svgLineEditor removeLineHandles];
}

// ================================================================

- (void)setToolMode:(NSUInteger)newToolMode
{
    NSButton * toolButton = arrowToolButton;
    
    switch (newToolMode)
    {
        case toolModeNone:
        {
            toolButton = arrowToolButton;
            break;
        }
        case toolModeArrowCursor:
        {
            toolButton = arrowToolButton;
            break;
        }
        case toolModeCrosshairCursor:
        {
            toolButton = crosshairToolButton;
            break;
        }
        case toolModeRect:
        {
            toolButton = rectToolButton;
            break;
        }
        case toolModeCircle:
        {
            toolButton = circleToolButton;
            break;
        }
        case toolModeEllipse:
        {
            toolButton = ellipseToolButton;
            break;
        }
        case toolModeText:
        {
            toolButton = textToolButton;
            break;
        }
        case toolModeImage:
        {
            toolButton = imageToolButton;
            break;
        }
        case toolModeLine:
        {
            toolButton = lineToolButton;
            break;
        }
        case toolModePolyline:
        {
            toolButton = polylineToolButton;
            break;
        }
        case toolModePolygon:
        {
            toolButton = polygonToolButton;
            break;
        }
        case toolModePath:
        {
            toolButton = pathToolButton;
            break;
        }
        case toolModePlugin:
        {
            toolButton = pluginToolButton;
            break;
        }
    }
    
    [self toolButtonAction:toolButton];
}

// ================================================================

- (IBAction)toolButtonAction:(id)sender
{
    NSUInteger previousToolMode = self.currentToolMode;
    
    switch (previousToolMode) 
    {
        case toolModePolyline:
            if (sender != polylineToolButton)
            {
                [self.svgWebKitController.domMouseEventsController.svgPolylineEditor deleteLastLineInPolyline];
                [self endPolylineDrawing];
            }
            break;
        case toolModePolygon:
            if (sender != polygonToolButton)
            {
                [self.svgWebKitController.domMouseEventsController.svgPolylineEditor deleteLastLineInPolyline];
                [self endPolylineDrawing];
            }
            break;
        case toolModeLine:
            if (sender != lineToolButton)
            {
                [self endLineDrawing];
            }
            break;
        case toolModePath:
            {
                [self endPathDrawing];
            }
            break;
        case toolModeCrosshairCursor:
            if (sender != crosshairToolButton)
            {
                [self endCrosshairCursorEditing];
            }
            break;
        default:
            break;
    }

    for (NSButton * aButton in toolButtonsArray)
    {
        if (aButton == sender)
        {
            NSUInteger objectIndex = [toolButtonsArray indexOfObject:aButton];
            self.currentToolMode = objectIndex;
            aButton.state = NSControlStateValueOn;            
        }
        else
        {
            aButton.state = NSControlStateValueOff;            
        }
    }
    (self.svgWebKitController.domMouseEventsController).mouseMode = MOUSE_DISENGAGED;

    if (self.currentToolMode != toolModePlugin)
    {
        [self showSettingsForCurrentToolMode];
    }
    
    if (previousToolMode == toolModeCrosshairCursor)
    {
        if (self.currentToolMode == toolModeArrowCursor)
        {
            NSInteger selectedElementCount = [self.svgXMLDOMSelectionManager.selectedElementsManager selectedElementsCount];
            if (selectedElementCount == 1)
            {
                NSXMLElement * selectedElement = [self.svgXMLDOMSelectionManager.selectedElementsManager xmlElementAtIndex:0];
                [self.svgXMLDOMSelectionManager selectXMLElement:selectedElement];
            }
        }
    }
    
    if (self.currentToolMode == toolModeCrosshairCursor)
    {
        NSInteger drawableSelectedElementCount = [self.svgXMLDOMSelectionManager.selectedElementsManager drawableSelectedElementsCount]; // omit counting of non-drawable elements like 'animate', etc.
        if (drawableSelectedElementCount == 1)
        {
            NSXMLElement * selectedElement = [self.svgXMLDOMSelectionManager.selectedElementsManager xmlElementAtIndex:0];
            [self.svgXMLDOMSelectionManager selectXMLElement:selectedElement];
            
            NSString * elementName = selectedElement.name;
            
            if ([elementName isEqualToString:@"path"] == YES)
            {
                [self.svgWebKitController.domMouseEventsController
                        handleCrosshairToolSelectionForPathXMLElement:selectedElement
                        handleDOMElement:NULL];
            }
            else if ([elementName isEqualToString:@"polyline"] == YES)
            {
                //[self.svgWebKitController.domMouseEventsController
                //        handleCrosshairToolSelectionForPolylineElement:selectedElement];

                [self.svgWebKitController.domMouseEventsController
                        handleCrosshairToolSelectionForPolylineXMLElement:selectedElement
                        handleDOMElement:NULL];
            }
            else if ([elementName isEqualToString:@"polygon"] == YES)
            {
                //[self.svgWebKitController.domMouseEventsController
                //        handleCrosshairToolSelectionForPolylineElement:selectedElement];

                [self.svgWebKitController.domMouseEventsController
                        handleCrosshairToolSelectionForPolylineXMLElement:selectedElement
                        handleDOMElement:NULL];
            }
            else if ([elementName isEqualToString:@"line"] == YES)
            {
                //[self.svgWebKitController.domMouseEventsController
                //        handleCrosshairToolSelectionForPolylineElement:selectedElement];

                [self.svgWebKitController.domMouseEventsController
                        handleCrosshairToolSelectionForLineXMLElement:selectedElement
                        handleDOMElement:NULL];
            }
        }
    }

    
    if (self.currentToolMode == toolModeImage)
    {
        // <svg> element requires xmlns:xlink="http://www.w3.org/1999/xlink"
        
        NSXMLNode * namespaceAttributeNode = [[NSXMLNode alloc] initWithKind:NSXMLNamespaceKind];
        namespaceAttributeNode.name = @"xlink";
        namespaceAttributeNode.stringValue = @"http://www.w3.org/1999/xlink";

        MacSVGDocument * macSVGDocument = self.document;
        NSXMLElement * rootElement = [macSVGDocument.svgXmlDocument rootElement];

        [rootElement addNamespace:namespaceAttributeNode];
    }
    
    
    self.svgXMLDOMSelectionManager.activeXMLElement = NULL;
    
    [self restoreSettingsForTool];
    
    NSOutlineView * svgXmlOutlineView = self.xmlOutlineController.xmlOutlineView;
    
    [svgXmlOutlineView.window makeFirstResponder:svgXmlOutlineView];

    [self setWebViewCursor];
}

// ================================================================

- (void)setWebViewCursor
{
    NSString * cursorName = @"crosshair";
    
    switch (self.currentToolMode)
    {
        case toolModeArrowCursor:
            {
                cursorName = @"default";
            }
            break;
        case toolModeCrosshairCursor:
            {
                cursorName = @"crosshair";
            }
            break;
        case toolModeText:
            {
                cursorName = @"default";
            }
            break;
        case toolModePlugin:
            {
                cursorName = @"pointer";
            }
            break;
        default:
                cursorName = @"crosshair";
            break;
    }

    DOMDocument * domDocument = (self.svgWebKitController.svgWebView).mainFrame.DOMDocument;
    DOMElement * svgElement = NULL;
	DOMNodeList * svgElementsList = [domDocument getElementsByTagNameNS:svgNamespace localName:@"svg"];
    if (svgElementsList.length > 0)
    {
        DOMNode * svgElementNode = [svgElementsList item:0];
        svgElement = (DOMElement *)svgElementNode;
        [svgElement setAttribute:@"cursor" value:cursorName];
    }
}

// ================================================================

- (void)selectXMLElement:(NSXMLElement *)selectedElement
{
    [self.svgXMLDOMSelectionManager selectXMLElement:selectedElement];
}

// ================================================================

- (void)beginPluginEditorToolMode
{
    [self toolButtonAction:pluginToolButton];
}

// ================================================================

- (void)beginArrowToolMode
{
    [self toolButtonAction:arrowToolButton];
}

// ================================================================

- (void)beginCrosshairToolMode
{
    [self toolButtonAction:crosshairToolButton];
}

// ================================================================

- (void) addDOMElementForXMLElement:(NSXMLElement *)aElement
{
    [self.svgWebKitController addDOMElementForXMLElement:aElement];
}

// ================================================================

- (void)identifySplitView:(NSSplitView *)splitView
        function:(NSString *)functionName
        dividerIndex:(NSInteger)dividerIndex
        proposedResult:(CGFloat)proposedResult
        result:(CGFloat)result
{
    NSString * splitViewName = splitView.description;
    
    if (splitView == fullWindowTopBottomSplitView)
    {
        splitViewName = @"fullWindowTopBottomSplitView";
    }

    if (splitView == leftMiddleRightSplitView)
    {
        splitViewName = @"leftMiddleRightSplitView";
    }
    
    if (splitView == elementsTopBottomSplitView)
    {
        splitViewName = @"elementsTopBottomSplitView";
    }

    if (splitView == attributesTopBottomSplitView)
    {
        splitViewName = @"attributesTopBottomSplitView";
    }

    if (splitView == timelineLeftRightSplitView)
    {
        splitViewName = @"timelineLeftRightSplitView";
    }
}

// ================================================================

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
    NSSplitView * splitView = (NSSplitView *)notification.object;
    
    if (splitView == leftMiddleRightSplitView)
    {
        NSView *leftSubview = (NSView *)splitView.subviews[0];
        NSRect leftSubviewFrame = leftSubview.frame;

        if (leftSubviewFrame.size.width < 188.0f)
        {
            leftSubviewFrame.size.width = 188.0f;
            leftSubview.frame = leftSubviewFrame;
        }
    }
    
    if (splitView == elementsTopBottomSplitView)
    {
        NSView * topSubview = (NSView *)splitView.subviews[0];
        NSRect topSubviewFrame = topSubview.frame;

        //if (topSubviewFrame.size.height < 226.0f)
        if (topSubviewFrame.size.height < 192.0f)
        {
            //topSubviewFrame.size.height = 226.0f;
            topSubviewFrame.size.height = 192.0f;
            topSubview.frame = topSubviewFrame;
        }
    }
}


// ================================================================

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview 
{
    return NO;
}

// ================================================================

- (void)windowDidEndLiveResize:(NSNotification *)notification
{
    NSArray * lmrSubviews = leftMiddleRightSplitView.subviews;
    NSView * leftSplitView = lmrSubviews.firstObject;
    NSRect leftSplitViewBounds = leftSplitView.bounds;
    if (leftSplitViewBounds.size.width < 188)
    {
        [leftMiddleRightSplitView setPosition:188 ofDividerAtIndex:0];
    }
    
    NSArray * topBottomSubviews = elementsTopBottomSplitView.subviews;
    NSView * topSplitView = topBottomSubviews.firstObject;
    NSRect topBottomViewBounds = topSplitView.bounds;
    if (topBottomViewBounds.size.height < 226)
    {
        //[elementsTopBottomSplitView setPosition:226 ofDividerAtIndex:0];
        [elementsTopBottomSplitView setPosition:192 ofDividerAtIndex:0];
    }
}

// ================================================================

- (CGFloat)splitView:(NSSplitView *)splitView 
        constrainMinCoordinate:(CGFloat)proposedMin 
        ofSubviewAt:(NSInteger)dividerIndex
{
    CGFloat result = proposedMin;

    if (splitView == fullWindowTopBottomSplitView)
    {
        result = 450;
    }
    else if (splitView == leftMiddleRightSplitView)
    {
        result = 250;
        
        if (dividerIndex == 0) result = 188;
    }
    else if (splitView == elementsTopBottomSplitView)
    {
        //result = 226;
        result = 192;
    }
    else if (splitView == attributesTopBottomSplitView)
    {
        //result = 320;
        result = 200;
    }
    else if (splitView == timelineLeftRightSplitView)
    {
        result = 200;
    }

    [self identifySplitView:splitView
            function:@"constrainMinCoordinate"
            dividerIndex:dividerIndex
            proposedResult:proposedMin
            result:result];

    return result;
}

// ================================================================

- (CGFloat)splitView:(NSSplitView *)splitView 
        constrainMaxCoordinate:(CGFloat)proposedMax 
        ofSubviewAt:(NSInteger)dividerIndex
{
    NSRect splitViewFrame = splitView.frame;
    float result = splitViewFrame.size.height - 250;

    if (splitView == fullWindowTopBottomSplitView)
    {
        result = splitViewFrame.size.height - 100;
    }
    else if (splitView == leftMiddleRightSplitView)
    {
        result = splitViewFrame.size.width - 250;
    }
    else if (splitView == elementsTopBottomSplitView)
    {
        result = splitViewFrame.size.height - 150;
    }
    else if (splitView == attributesTopBottomSplitView)
    {
        result = splitViewFrame.size.height - 150;
    }
    else if (splitView == timelineLeftRightSplitView)
    {
        result = splitViewFrame.size.width - 250;
    }
    
    [self identifySplitView:splitView
            function:@"constrainMaxCoordinate"
            dividerIndex:dividerIndex
            proposedResult:proposedMax
            result:result];
    
    return result;
}

// ================================================================

- (CGFloat)splitView:(NSSplitView *)splitView
        constrainSplitPosition:(CGFloat)proposedPosition
        ofSubviewAt:(NSInteger)dividerIndex
{
    CGFloat result = proposedPosition;

    if (splitView == fullWindowTopBottomSplitView)
    {
    
    }
    else if (splitView == leftMiddleRightSplitView)
    {

    }
    else if (splitView == elementsTopBottomSplitView)
    {
    
    }
    else if (splitView == attributesTopBottomSplitView)
    {
    
    }
    else if (splitView == timelineLeftRightSplitView)
    {
    
    }

    [self identifySplitView:splitView
            function:@"constrainSplitPosition"
            dividerIndex:dividerIndex
            proposedResult:proposedPosition
            result:result];
    
    return result;
}

// ================================================================

- (void)setElementsButtonPosition:(NSButton *)aButton
        position:(NSUInteger)position
{
    NSView * parentView = aButton.superview;
    NSRect parentFrame = parentView.frame;
    
    float buttonWidthFloat = parentFrame.size.width / 2.0f;
    NSUInteger buttonWidth = (NSUInteger)buttonWidthFloat;
    
    NSRect buttonFrame = aButton.frame;
    buttonFrame.origin.x = position * buttonWidth;
    buttonFrame.size.width = buttonWidth;
    aButton.frame = buttonFrame;
}

// ================================================================

- (void)setToolButtonPosition:(NSButton *)aButton row:(NSUInteger)row
        column:(NSUInteger)column
{
    NSView * parentView = aButton.superview;
    NSRect parentFrame = parentView.frame;
    
    float buttonWidthFloat = parentFrame.size.width / 4.0f;
    NSUInteger buttonWidth = (NSUInteger)buttonWidthFloat;
    
    NSRect buttonFrame = aButton.frame;
    buttonFrame.origin.x = column * buttonWidth;
    buttonFrame.size.width = buttonWidth;
    aButton.frame = buttonFrame;
    
    aButton.image = NULL;   // replace bitmap icons with Core Graphics in MacSVGIconButton
}

// ================================================================

- (void)setColorWellPosition:(NSColorWell *)aColorWell row:(NSUInteger)row
        column:(NSUInteger)column
{
    NSView * parentView = aColorWell.superview;
    NSRect parentFrame = parentView.frame;
    
    float widthFloat = parentFrame.size.width / 4.0f;
    NSUInteger width = (NSUInteger)widthFloat;
    
    NSRect newFrame = aColorWell.frame;
    newFrame.origin.x = column * width;
    newFrame.size.width = width;
    aColorWell.frame = newFrame;
}

// ================================================================

- (void)resizeToolButtons
{
    [self setElementsButtonPosition:svgToolsButton position:0];
    [self setElementsButtonPosition:svgElementsButton position:1];

    [self setToolButtonPosition:arrowToolButton row:0 column:0];
    [self setToolButtonPosition:crosshairToolButton row:1 column:0];
    [self setToolButtonPosition:rectToolButton row:0 column:1];
    [self setToolButtonPosition:circleToolButton row:0 column:2];
    [self setToolButtonPosition:ellipseToolButton row:0 column:3];
    [self setToolButtonPosition:textToolButton row:1 column:1];
    [self setToolButtonPosition:imageToolButton row:1 column:2];
    [self setToolButtonPosition:lineToolButton row:1 column:3];
    [self setToolButtonPosition:pluginToolButton row:2 column:0];
    [self setToolButtonPosition:polylineToolButton row:2 column:1];
    [self setToolButtonPosition:polygonToolButton row:2 column:2];
    [self setToolButtonPosition:pathToolButton row:2 column:3];
}

// ================================================================

/*
- (void) handlePluginEvent:(DOMEvent *)event
{
    [self.svgWebKitController.domMouseEventsController handlePluginEvent:event];

    [self.editorUIFrameController handlePluginEvent:event];
}
*/

// ================================================================

- (NSMutableArray *) contextMenuItemsForPlugin
{
    return [self.editorUIFrameController contextMenuItemsForPlugin];
}

// ================================================================

- (IBAction)enableAnimationCheckboxAction:(id)sender;
{
    NSIndexSet * xmlOutlineSelectedRowIndexes = self.xmlOutlineController.xmlOutlineView.selectedRowIndexes;
    NSIndexSet * xmlAttributesSelectedRowIndexes =  self.xmlAttributesTableController.xmlAttributesTableView.selectedRowIndexes;

    [self reloadAllViews];
    
    if (self.enableAnimationCheckbox.state == YES)
    {
        NSImage * buttonImage = [NSImage imageNamed:@"Pause16"];
        (self.pausePlayAnimationButton).image = buttonImage;
    }
    else
    {
        NSImage * buttonImage = [NSImage imageNamed:@"NSGoRightTemplate"];
        (self.pausePlayAnimationButton).image = buttonImage;
    }
    
    [self.xmlOutlineController.xmlOutlineView selectRowIndexes:xmlOutlineSelectedRowIndexes byExtendingSelection:NO];
    [self.xmlAttributesTableController.xmlAttributesTableView selectRowIndexes:xmlAttributesSelectedRowIndexes byExtendingSelection:NO];
}

// ================================================================

- (void) setDOMVisibility:(NSString *)visibility forMacsvgid:(NSString *)macsvgid
{
    [self.svgWebKitController setDOMVisibility:visibility forMacsvgid:macsvgid];
}

// ================================================================

- (NSString *)hostString
{
    NSString * hostString = @"error";
    struct ifaddrs * interfaces = NULL;
    struct ifaddrs * temp_addr = NULL;
    int success = 0;

    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                    // Get NSString from C String
                    hostString = @(inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr));
            }
            temp_addr = temp_addr->ifa_next;
        }
    }

    // Free memory
    freeifaddrs(interfaces);

    return hostString;
}

// ================================================================

- (NSString *)portString
{
    MacSVGAppDelegate * macSVGAppDelegate = (MacSVGAppDelegate *)NSApp.delegate;
    WebServerController * webServerController = macSVGAppDelegate.webServerController;

    NSUInteger webHostPort = webServerController.webServerPort;
    
    NSString * portString = [NSString stringWithFormat:@"%lu", (unsigned long)webHostPort];
    
    return portString;
}

// ================================================================

- (NSString *)webPreviewURLString
{
    NSString * urlString = @"HTTP Server Not Enabled";

    MacSVGAppDelegate * macSVGAppDelegate = (MacSVGAppDelegate *)NSApp.delegate;
    WebServerController * webServerController = macSVGAppDelegate.webServerController;
    
    if (webServerController.httpServer != NULL)
    {
        NSString * hostString = [self hostString];
        //NSString * hostString = [[NSHost currentHost] localizedName]; // doesn't work - Safari won't find capitalized hosts
        
        NSString * portString = [self portString];

        urlString = [NSString stringWithFormat:@"http://%@:%@", hostString, portString];
    }
    
    return urlString;
}

// ================================================================

- (void)showWebBrowserPreviewURL;
{
    NSString * urlString = [self webPreviewURLString];

    webBrowserPreviewButton.title = urlString;

    MacSVGAppDelegate * macSVGAppDelegate = (MacSVGAppDelegate *)NSApp.delegate;
    WebServerController * webServerController = macSVGAppDelegate.webServerController;
    
    if (webServerController.httpServer != NULL)
    {
        webBrowserPreviewButton.enabled = YES;
        shareWebPreviewURLButton.enabled = YES;
    }
    else
    {
        webBrowserPreviewButton.enabled = NO;
        shareWebPreviewURLButton.enabled = NO;
    }
}

// ================================================================

- (IBAction)launchWebBrowserPreview:(id)sender;
{
    NSString * urlString = [self webPreviewURLString];
    
    NSURL * url = [NSURL URLWithString:urlString];

    [[NSWorkspace sharedWorkspace] openURL:url];
}

// -------------------------------------------------------------------------------
//  showPopoverAction:sender
// -------------------------------------------------------------------------------
- (IBAction)showPopoverAction:(id)sender
{
    NSButton *targetButton = (NSButton *)sender;
    
    // configure the preferred position of the popover
    [self.toolSettingsPopover showRelativeToRect:targetButton.bounds ofView:sender preferredEdge:NSMaxXEdge];
}

// -------------------------------------------------------------------------------
//  assignElementIDIfUnassigned:
// -------------------------------------------------------------------------------

- (void) assignElementIDIfUnassigned:(NSXMLNode *)aNode
{
    MacSVGDocument * macSVGDocument = self.document;
    [macSVGDocument assignElementIDIfUnassigned:aNode];
}

// -------------------------------------------------------------------------------
//  assignElementIDIfUnassigned:
// -------------------------------------------------------------------------------

- (NSString *)uniqueIDForElementTagName:(NSString *)tagName
{
    MacSVGDocument * macSVGDocument = self.document;
    return [macSVGDocument uniqueIDForElementTagName:tagName pendingIDs:NULL];
}

// -------------------------------------------------------------------------------
//  newMacsvgid
// -------------------------------------------------------------------------------

- (NSString *)newMacsvgid
{
    MacSVGDocument * macSVGDocument = self.document;
    NSString * macsvgid = [macSVGDocument newMacsvgid];
    return macsvgid;
}

//==================================================================================
//	hexadecimalValueOfAnNSColor
//==================================================================================

-(NSString *)hexadecimalValueOfAnNSColor:(NSColor *)aColor
{
    CGFloat redFloatValue, greenFloatValue, blueFloatValue;
    int redIntValue, greenIntValue, blueIntValue;
    NSString *redHexValue, *greenHexValue, *blueHexValue;

    // Convert the NSColor to the RGB color space before we can access its components
    //NSColor * convertedColor = [aColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSColor * convertedColor = [aColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];

    if(convertedColor)
    {
        // Get the red, green, and blue components of the color
        [convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];

        // Convert the components to numbers (unsigned decimal integer) between 0 and 255
        redIntValue = redFloatValue * 255.99999f;
        greenIntValue = greenFloatValue * 255.99999f;
        blueIntValue = blueFloatValue * 255.99999f;

        // Convert the numbers to hex strings
        redHexValue=[NSString stringWithFormat:@"%02x", redIntValue]; 
        greenHexValue=[NSString stringWithFormat:@"%02x", greenIntValue];
        blueHexValue=[NSString stringWithFormat:@"%02x", blueIntValue];

        // Concatenate the red, green, and blue components' hex strings together with a "#"
        return [NSString stringWithFormat:@"#%@%@%@", redHexValue, greenHexValue, blueHexValue];
    }
    return nil;
}

//==================================================================================
//	numericStringWithFloat
//==================================================================================

- (NSString *)numericStringWithFloat:(float)attributeFloat
{
    NSString * numericString = @"0";

    numericString = [NSString stringWithFormat:@"%f", attributeFloat];
    
    NSRange decimalPointRange = [numericString rangeOfString:@"."];
    if (decimalPointRange.location != NSNotFound)
    {
        NSInteger index = numericString.length - 1;
        BOOL continueTrim = YES;
        while (continueTrim == YES)
        {
            if ([numericString characterAtIndex:index] == '0')
            {
                index--;
            }
            else if ([numericString characterAtIndex:index] == '.')
            {
                index--;
                continueTrim = NO;
            }
            else
            {
                continueTrim = NO;
            }
            
            if (index < decimalPointRange.location)
            {
                continueTrim = NO;
            }
        }
        
        numericString = [numericString substringToIndex:index + 1];
    }
    

    return numericString;
}

//==================================================================================
//	hexColorFromColorWell
//==================================================================================

- (NSString *)hexColorFromColorWell:(NSColorWell *)aColorWell
{
    NSColor * aColor = aColorWell.color;
    
    NSString * hexColor = [self hexadecimalValueOfAnNSColor:aColor];
    
    return hexColor;
}

//==================================================================================
//	strokeColorString
//==================================================================================

- (NSString *)strokeColorString
{
    NSString * strokeColorString = [self hexColorFromColorWell:self.strokeColorWell];
    
    if (self.strokeCheckboxButton.state == 0)
    {
        strokeColorString = @"none";
    }
    
    return strokeColorString;
}

//==================================================================================
//	fillColorString
//==================================================================================

- (NSString *)fillColorString
{
    NSString * fillColorString = [self hexColorFromColorWell:self.fillColorWell];
    
    if (self.fillCheckboxButton.state == 0)
    {
        fillColorString = @"none";
    }
    
    return fillColorString;
}

//==================================================================================
//	strokeWidthString
//==================================================================================

- (NSString *)strokeWidthString
{
    NSString * strokeWidthTextFieldValue = (self.strokeWidthTextField).stringValue;
    float strokeWidthFloat = strokeWidthTextFieldValue.floatValue;
    NSString * strokeWidthNumericString = [self numericStringWithFloat:strokeWidthFloat];
    
    NSString * strokeWidthUnitString = (self.strokeWidthUnitPopUpButton).titleOfSelectedItem;
    
    NSString * strokeWidthString = [NSString stringWithFormat:@"%@%@",
            strokeWidthNumericString, strokeWidthUnitString];
    
    return strokeWidthString;
}

//==================================================================================
//	strokeCheckboxButtonAction
//==================================================================================

- (IBAction)strokeCheckboxButtonAction:(id)sender
{
    [self preserveSettingsForTool];
}

//==================================================================================
//	fillCheckboxButtonAction
//==================================================================================

- (IBAction)fillCheckboxButtonAction:(id)sender
{
    [self preserveSettingsForTool];
}

//==================================================================================
//	strokeColorWellAction
//==================================================================================

- (IBAction)strokeColorWellAction:(id)sender
{
    [self preserveSettingsForTool];
}

//==================================================================================
//	fillColorWellAction
//==================================================================================

- (IBAction)fillColorWellAction:(id)sender
{
    [self preserveSettingsForTool];
}

//==================================================================================
//	strokeWidthStepperAction
//==================================================================================

- (IBAction)strokeWidthStepperAction:(id)sender
{
    [self preserveSettingsForTool];
}

//==================================================================================
//	strokeWidthTextFieldAction
//==================================================================================

- (IBAction)strokeWidthTextFieldAction:(id)sender
{
    [self preserveSettingsForTool];
}

//==================================================================================
//	strokeWidthUnitPopUpButtonAction
//==================================================================================

- (IBAction)strokeWidthUnitPopUpButtonAction:(id)sender
{
    [self preserveSettingsForTool];
}

//==================================================================================
//	preserveSettingsForTool
//==================================================================================

- (void)preserveSettingsForTool
{
    BOOL strokeEnabled = (self.strokeCheckboxButton).integerValue;
    BOOL fillEnabled = (self.fillCheckboxButton).integerValue;
    float strokeWidth = (self.strokeWidthTextField).floatValue;
    NSString * unitString = (self.strokeWidthUnitPopUpButton).titleOfSelectedItem;
    NSColor * strokeColor = (self.strokeColorWell).color;
    NSColor * fillColor = (self.fillColorWell).color;

    switch (self.currentToolMode)
    {
        case toolModeNone:
        {
            break;
        }
        case toolModeArrowCursor:
        {
            break;
        }
        case toolModeCrosshairCursor:
        {
            break;
        }
        case toolModeRect:
        {
            self.rectStrokeEnabled = strokeEnabled;
            self.rectFillEnabled = fillEnabled;
            self.rectStrokeWidth = strokeWidth;
            self.rectUnit = unitString;
            self.rectStrokeColor = strokeColor;
            self.rectFillColor = fillColor;
            break;
        }
        case toolModeCircle:
        {
            self.circleStrokeEnabled = strokeEnabled;
            self.circleFillEnabled = fillEnabled;
            self.circleStrokeWidth = strokeWidth;
            self.circleUnit = unitString;
            self.circleStrokeColor = strokeColor;
            self.circleFillColor = fillColor;
            break;
        }
        case toolModeEllipse:
        {
            self.ellipseStrokeEnabled = strokeEnabled;
            self.ellipseFillEnabled = fillEnabled;
            self.ellipseStrokeWidth = strokeWidth;
            self.ellipseUnit = unitString;
            self.ellipseStrokeColor = strokeColor;
            self.ellipseFillColor = fillColor;
            break;
        }
        case toolModeText:
        {
            self.textStrokeEnabled = strokeEnabled;
            self.textFillEnabled = fillEnabled;
            self.textStrokeWidth = strokeWidth;
            self.textUnit = unitString;
            self.textStrokeColor = strokeColor;
            self.textFillColor = fillColor;
            break;
        }
        case toolModeImage:
        {
            self.imageStrokeEnabled = strokeEnabled;
            self.imageFillEnabled = fillEnabled;
            self.imageStrokeWidth = strokeWidth;
            self.imageUnit = unitString;
            self.imageStrokeColor = strokeColor;
            self.imageFillColor = fillColor;
            break;
        }
        case toolModeLine:
        {
            self.lineStrokeEnabled = strokeEnabled;
            self.lineFillEnabled = fillEnabled;
            self.lineStrokeWidth = strokeWidth;
            self.lineUnit = unitString;
            self.lineStrokeColor = strokeColor;
            self.lineFillColor = fillColor;
            break;
        }
        case toolModePolyline:
        {
            self.polylineStrokeEnabled = strokeEnabled;
            self.polylineFillEnabled = fillEnabled;
            self.polylineStrokeWidth = strokeWidth;
            self.polylineUnit = unitString;
            self.polylineStrokeColor = strokeColor;
            self.polylineFillColor = fillColor;
            break;
        }
        case toolModePolygon:
        {
            self.polygonStrokeEnabled = strokeEnabled;
            self.polygonFillEnabled = fillEnabled;
            self.polygonStrokeWidth = strokeWidth;
            self.polygonUnit = unitString;
            self.polygonStrokeColor = strokeColor;
            self.polygonFillColor = fillColor;
            break;
        }
        case toolModePath:
        {
            self.pathStrokeEnabled = strokeEnabled;
            self.pathFillEnabled = fillEnabled;
            self.pathStrokeWidth = strokeWidth;
            self.pathUnit = unitString;
            self.pathStrokeColor = strokeColor;
            self.pathFillColor = fillColor;
            break;
        }
        case toolModePlugin:
        {
            break;
        }
    }
}

//==================================================================================
//	restoreSettingsForTool
//==================================================================================

- (void)restoreSettingsForTool
{
    BOOL strokeEnabled = (self.strokeCheckboxButton).integerValue;
    BOOL fillEnabled = (self.fillCheckboxButton).integerValue;
    float strokeWidth = (self.strokeWidthTextField).floatValue;
    NSString * unitString = (self.strokeWidthUnitPopUpButton).titleOfSelectedItem;
    NSColor * strokeColor = (self.strokeColorWell).color;
    NSColor * fillColor = (self.fillColorWell).color;

    switch (self.currentToolMode)
    {
        case toolModeNone:
        {
            break;
        }
        case toolModeArrowCursor:
        {
            break;
        }
        case toolModeCrosshairCursor:
        {
            break;
        }
        case toolModeRect:
        {
            strokeEnabled = self.rectStrokeEnabled;
            fillEnabled = self.rectFillEnabled;
            strokeWidth = self.rectStrokeWidth;
            unitString = self.rectUnit;
            strokeColor = self.rectStrokeColor;
            fillColor = self.rectFillColor;
            break;
        }
        case toolModeCircle:
        {
            strokeEnabled = self.circleStrokeEnabled;
            fillEnabled = self.circleFillEnabled;
            strokeWidth = self.circleStrokeWidth;
            unitString = self.circleUnit;
            strokeColor = self.circleStrokeColor;
            fillColor = self.circleFillColor;
            break;
        }
        case toolModeEllipse:
        {
            strokeEnabled = self.ellipseStrokeEnabled;
            fillEnabled = self.ellipseFillEnabled;
            strokeWidth = self.ellipseStrokeWidth;
            unitString = self.ellipseUnit;
            strokeColor = self.ellipseStrokeColor;
            fillColor = self.ellipseFillColor;
            break;
        }
        case toolModeText:
        {
            strokeEnabled = self.textStrokeEnabled;
            fillEnabled = self.textFillEnabled;
            strokeWidth = self.textStrokeWidth;
            unitString = self.textUnit;
            strokeColor = self.textStrokeColor;
            fillColor = self.textFillColor;
            break;
        }
        case toolModeImage:
        {
            strokeEnabled = self.imageStrokeEnabled;
            fillEnabled = self.imageFillEnabled;
            strokeWidth = self.imageStrokeWidth;
            unitString = self.imageUnit;
            strokeColor = self.imageStrokeColor;
            fillColor = self.imageFillColor;
            break;
        }
        case toolModeLine:
        {
            strokeEnabled = self.lineStrokeEnabled;
            fillEnabled = self.lineFillEnabled;
            strokeWidth = self.lineStrokeWidth;
            unitString = self.lineUnit;
            strokeColor = self.lineStrokeColor;
            fillColor = self.lineFillColor;
            break;
        }
        case toolModePolyline:
        {
            strokeEnabled = self.polylineStrokeEnabled;
            fillEnabled = self.polylineFillEnabled;
            strokeWidth = self.polylineStrokeWidth;
            unitString = self.polylineUnit;
            strokeColor = self.polylineStrokeColor;
            fillColor = self.polylineFillColor;
            break;
        }
        case toolModePolygon:
        {
            strokeEnabled = self.polygonStrokeEnabled;
            fillEnabled = self.polygonFillEnabled;
            strokeWidth = self.polygonStrokeWidth;
            unitString = self.polygonUnit;
            strokeColor = self.polygonStrokeColor;
            fillColor = self.polygonFillColor;
            break;
        }
        case toolModePath:
        {
            strokeEnabled = self.pathStrokeEnabled;
            fillEnabled = self.pathFillEnabled;
            strokeWidth = self.pathStrokeWidth;
            unitString = self.pathUnit;
            strokeColor = self.pathStrokeColor;
            fillColor = self.pathFillColor;
            break;
        }
        case toolModePlugin:
        {
            break;
        }
    }

    (self.strokeCheckboxButton).state = strokeEnabled;
    (self.fillCheckboxButton).state = fillEnabled;
    (self.strokeWidthTextField).floatValue = strokeWidth;
    [self.strokeWidthUnitPopUpButton selectItemWithTitle:unitString];
    (self.strokeColorWell).color = strokeColor;
    (self.fillColorWell).color = fillColor;
}

//==================================================================================
// setDefaultToolSettings
//==================================================================================

- (void)setDefaultToolSettings
{
    self.rectStrokeEnabled = YES;
    self.rectFillEnabled = YES;
    self.rectStrokeWidth = 3.0f;
    self.rectUnit = @"px";
    self.rectStrokeColor = [NSColor blackColor];
    self.rectFillColor = [NSColor whiteColor];

    self.circleStrokeEnabled = YES;
    self.circleFillEnabled = YES;
    self.circleStrokeWidth = 3.0f;
    self.circleUnit = @"px";
    self.circleStrokeColor = [NSColor blackColor];
    self.circleFillColor = [NSColor whiteColor];

    self.ellipseStrokeEnabled = YES;
    self.ellipseFillEnabled = YES;
    self.ellipseStrokeWidth = 3.0f;
    self.ellipseUnit = @"px";
    self.ellipseStrokeColor = [NSColor blackColor];
    self.ellipseFillColor = [NSColor whiteColor];

    self.polylineStrokeEnabled = YES;
    self.polylineFillEnabled = NO;
    self.polylineStrokeWidth = 3.0f;
    self.polylineUnit = @"px";
    self.polylineStrokeColor = [NSColor blackColor];
    self.polylineFillColor = [NSColor whiteColor];

    self.polygonStrokeEnabled = YES;
    self.polygonFillEnabled = YES;
    self.polygonStrokeWidth = 3.0f;
    self.polygonUnit = @"px";
    self.polygonStrokeColor = [NSColor blackColor];
    self.polygonFillColor = [NSColor whiteColor];

    self.lineStrokeEnabled = YES;
    self.lineFillEnabled = NO;
    self.lineStrokeWidth = 3.0f;
    self.lineUnit = @"px";
    self.lineStrokeColor = [NSColor blackColor];
    self.lineFillColor = [NSColor whiteColor];

    self.textStrokeEnabled = NO;
    self.textFillEnabled = YES;
    self.textStrokeWidth = 1.0f;
    self.textUnit = @"px";
    self.textStrokeColor = [NSColor redColor];
    self.textFillColor = [NSColor blackColor];

    self.imageStrokeEnabled = NO;
    self.imageFillEnabled = NO;
    self.imageStrokeWidth = 1.0f;
    self.imageUnit = @"px";
    self.imageStrokeColor = [NSColor blackColor];
    self.imageFillColor = [NSColor whiteColor];

    self.pathStrokeEnabled = YES;
    self.pathFillEnabled = NO;
    self.pathStrokeWidth = 3.0f;
    self.pathUnit = @"px";
    self.pathStrokeColor = [NSColor blackColor];
    self.pathFillColor = [NSColor whiteColor];
}

//==================================================================================
// findElement
//==================================================================================

- (IBAction)findElement:(id)sender
{
    [svgSearchField.window makeFirstResponder:svgSearchField];
}

//==================================================================================
// findNextElement
//==================================================================================

- (IBAction)findNextElement:(id)sender
{
    [svgSearchField.window makeFirstResponder:svgSearchField];

    NSString * svgSearchText = svgSearchField.stringValue;
    
    NSXMLElement * foundElement = NULL;
    
    MacSVGDocument * macSVGDocument = self.document;
    NSXMLElement * rootElement = [macSVGDocument.svgXmlDocument rootElement];
    
    NSInteger selectedRow = (self.xmlOutlineController.xmlOutlineView).selectedRow;
    NSXMLElement * findAfterElement = NULL;
    
    if (selectedRow != -1)
    {
        NSXMLNode * findAfterNode = [self.xmlOutlineController.xmlOutlineView itemAtRow:selectedRow];
        if (findAfterNode.kind == NSXMLElementKind)
        {
            findAfterElement = (NSXMLElement *)findAfterNode;
        }
        else
        {
            findAfterElement = (NSXMLElement *)findAfterNode.parent;
        }
    }

    foundElement = [self searchElementsInParent:rootElement forString:svgSearchText
            findAfterElement:findAfterElement];
    
    if (foundElement != NULL)
    {
        [self expandElementInOutline:foundElement];
        [self.xmlOutlineController selectElement:foundElement];
    }
    else
    {
        [self.xmlOutlineController.xmlOutlineView deselectAll:self];
    }
}

//==================================================================================
// svgSearchFieldAction
//==================================================================================

- (IBAction)svgSearchFieldAction:(id)sender
{
    NSString * svgSearchText = svgSearchField.stringValue;
    
    NSXMLElement * foundElement = NULL;
    
    MacSVGDocument * macSVGDocument = self.document;
    NSXMLElement * rootElement = [macSVGDocument.svgXmlDocument rootElement];
    
    BOOL result = [self searchInElement:rootElement forString:svgSearchText];
    
    if (result == YES)
    {
        foundElement = rootElement;
    }
    else
    {
        foundElement = [self searchElementsInParent:rootElement forString:svgSearchText findAfterElement:NULL];
    }
    
    if (foundElement != NULL)
    {
        [self expandElementInOutline:foundElement];
        [self.xmlOutlineController selectElement:foundElement];
    }
    else
    {
        [self.xmlOutlineController.xmlOutlineView deselectAll:self];
    }
}

//==================================================================================
// searchInElement:forString:
//==================================================================================

- (BOOL)searchInElement:(NSXMLElement *)searchElement forString:(NSString *)searchString
{
    BOOL result = NO;
    
    NSString * tagName = searchElement.name;
    
    NSRange foundRange = [tagName rangeOfString:searchString options:NSCaseInsensitiveSearch];
    
    if (foundRange.location != NSNotFound)
    {
        result = YES;
    }
    else
    {
        NSArray * attributesArray = searchElement.attributes;
        
        for (NSXMLNode * aAttribute in attributesArray)
        {
            NSString * attributeName = aAttribute.name;
            foundRange = [attributeName rangeOfString:searchString options:NSCaseInsensitiveSearch];
            if (foundRange.location != NSNotFound)
            {
                result = YES;
                break;
            }

            NSString * attributeValue = aAttribute.stringValue;
            foundRange = [attributeValue rangeOfString:searchString options:NSCaseInsensitiveSearch];
            if (foundRange.location != NSNotFound)
            {
                result = YES;
                break;
            }
        }
    }
    
    return result;
}

//==================================================================================
// searchElementsInParent:forString:
//==================================================================================

- (NSXMLElement *)searchElementsInParent:(NSXMLElement *)parentElement
        forString:(NSString *)searchString findAfterElement:(NSXMLElement *)findAfterElement
{
    NSXMLElement * foundElement = NULL;
    BOOL previousElementWasFound = NO;
    
    if (findAfterElement == NULL)
    {
        previousElementWasFound = YES;
    }
    
    if (parentElement == findAfterElement)
    {
        previousElementWasFound = YES;
    }
    
    NSArray * childNodes = parentElement.children;
    for (NSXMLNode * aChildNode in childNodes)
    {
        if (aChildNode.kind == NSXMLElementKind)
        {
            NSXMLElement * childElement = (NSXMLElement *)aChildNode;
            
            if (previousElementWasFound == YES)
            {
                BOOL result = [self searchInElement:childElement forString:searchString];
                
                if (result == YES)
                {
                    foundElement = childElement;
                    break;
                }
                else
                {
                    foundElement = [self searchElementsInParent:childElement forString:searchString
                            findAfterElement:NULL];   // recursive search
                    if (foundElement != NULL)
                    {
                        break;
                    }
                }
            }
            else
            {
                if (childElement == findAfterElement)
                {
                    previousElementWasFound = YES;
                    
                    foundElement = [self searchElementsInParent:childElement forString:searchString
                            findAfterElement:NULL];   // recursive search
                    if (foundElement != NULL)
                    {
                        break;
                    }
                }
                else
                {
                    foundElement = [self searchElementsInParent:childElement forString:searchString
                            findAfterElement:findAfterElement];   // recursive search
                    if (foundElement != NULL)
                    {
                        break;
                    }
                }
            }
        }
    }
    
    return foundElement;
}

//==================================================================================
// showElementDocumentation:
//==================================================================================

- (IBAction)showElementDocumentation:(id)sender
{
    
    NSString * elementTag = @"svg";
    
    BOOL tryOutlineFirst = NO;

    if (self.window.firstResponder == self.xmlOutlineController.xmlOutlineView)
    {
        tryOutlineFirst = YES;
    }
    
    if (svgElementsButton.state == 1)
    {
        tryOutlineFirst = NO;
    }
    
    if (tryOutlineFirst == YES)
    {
        NSArray * outlineSelectedItemsArray = self.xmlOutlineController.selectedItems;
        
        if (outlineSelectedItemsArray.count > 0)
        {
            NSXMLElement * selectedElement = [outlineSelectedItemsArray objectAtIndex:0];
            
            elementTag = selectedElement.name;
        }
        else
        {
            NSInteger selectedRow = (self.svgElementsTableController.elementsTableView).selectedRow;

            if (selectedRow >= 0)
            {
                elementTag = (self.svgElementsTableController.svgElementsArray)[selectedRow];
            }
        }
    }
    else
    {
        NSInteger selectedRow = (self.svgElementsTableController.elementsTableView).selectedRow;

        if (selectedRow >= 0)
        {
            elementTag = (self.svgElementsTableController.svgElementsArray)[selectedRow];
        }
        else
        {
            NSArray * outlineSelectedItemsArray = self.xmlOutlineController.selectedItems;
            
            if (outlineSelectedItemsArray.count > 0)
            {
                NSXMLElement * selectedElement = [outlineSelectedItemsArray objectAtIndex:0];
                
                elementTag = selectedElement.name;
            }
        }
    }

    [self.svgHelpManager showDocumentationForElement:elementTag];
}

//==================================================================================
// showAttributeDocumentation:
//==================================================================================

- (IBAction)showAttributeDocumentation:(id)sender
{
    id firstResponder = (self.window).firstResponder;
    
    NSString * attributeName = NULL;
    
    if (self.xmlAttributesTableController.xmlAttributesTableView == firstResponder)
    {
        NSInteger selectedRow = (self.xmlAttributesTableController.xmlAttributesTableView).selectedRow;

        NSDictionary * attributeDictionary = (self.xmlAttributesTableController.xmlAttributesArray)[selectedRow];

        attributeName = attributeDictionary[@"name"];
    }
    
    if (self.editorUIFrameController.validAttributesController.validAttributesTableView == firstResponder)
    {
        NSInteger selectedRow = (self.editorUIFrameController.validAttributesController.validAttributesTableView).selectedRow;
        
        attributeName = (self.editorUIFrameController.validAttributesController.attributeKeysArray)[selectedRow];
    }

    if (attributeName != NULL)
    {
        [self.svgHelpManager showDocumentationForAttribute:attributeName];
    }
}

//==================================================================================
// addCSSStyleName:styleValue:toXMLElement:
//==================================================================================

- (NSString *)addCSSStyleName:(NSString *)styleName styleValue:(NSString *)styleValue toXMLElement:(NSXMLElement *)targetElement
{
    return [self.xmlOutlineController addCSSStyleName:styleName styleValue:styleValue toXMLElement:targetElement];
}

//==================================================================================
// addCSSStyleName:styleValue:toDOMElement:
//==================================================================================

- (NSString *)addCSSStyleName:(NSString *)styleName styleValue:(NSString *)styleValue toDOMElement:(DOMElement *)targetElement
{
    return [self.xmlOutlineController addCSSStyleName:styleName styleValue:styleValue toDOMElement:targetElement];
}

//==================================================================================
// zoomIn:
//==================================================================================

- (IBAction)zoomIn:(id)sender
{
    NSScrollView * webScrollView = [[[[self.svgWebKitController.svgWebView mainFrame] frameView] documentView] enclosingScrollView];
    
    NSRect documentVisibleRect = webScrollView.documentVisibleRect;

    float zoomFactor = self.svgWebKitController.svgWebView.zoomFactor;
    
    zoomFactor *= 2.0f;
    
    NSPoint scrollToPoint = NSZeroPoint;
    
    if ((documentVisibleRect.origin.x > 0) || (documentVisibleRect.origin.y > 0))
    {
        CGFloat newMidX = (documentVisibleRect.origin.x + (documentVisibleRect.size.width / 4.0f)) * 2.0f;
        CGFloat newMidY = (documentVisibleRect.origin.y + (documentVisibleRect.size.height / 4.0f)) * 2.0f;
        scrollToPoint = NSMakePoint(newMidX, newMidY);
    }
    
    [self.svgWebKitController.svgWebView setSVGZoomStyleWithFloat:zoomFactor];

    [self.svgWebKitController setScrollToPoint:scrollToPoint];
    
    [self reloadAllViews];
}

//==================================================================================
// zoomOut:
//==================================================================================

- (IBAction)zoomOut:(id)sender
{
    NSScrollView * webScrollView = [[[[self.svgWebKitController.svgWebView mainFrame] frameView] documentView] enclosingScrollView];

    NSRect documentVisibleRect = webScrollView.documentVisibleRect;

    CGFloat scaleFactor = 0.5f;
    
    CGFloat zoomFactor = self.svgWebKitController.svgWebView.zoomFactor * scaleFactor;
    
    CGFloat newMidX = (documentVisibleRect.origin.x * scaleFactor) - ((documentVisibleRect.size.width * scaleFactor) / 2.0f);
    CGFloat newMidY = (documentVisibleRect.origin.y * scaleFactor) - ((documentVisibleRect.size.height * scaleFactor) / 2.0f);
    NSPoint scrollToPoint = NSMakePoint(newMidX, newMidY);
    
    [self.svgWebKitController.svgWebView setSVGZoomStyleWithFloat:zoomFactor];

    [self.svgWebKitController setScrollToPoint:scrollToPoint];

    [self reloadAllViews];
}

//==================================================================================
// resetZoom:
//==================================================================================

- (IBAction)resetZoom:(id)sender
{
    [self.svgWebKitController.svgWebView setSVGZoomStyleWithFloat:1.0f];

    [self reloadAllViews];
}

//==================================================================================
// exportImages:
//==================================================================================

- (IBAction)exportImages:(id)sender
{
    NSWindow * hostWindow = self.window;

    DOMDocument * domDocument = (self.svgWebKitController.svgWebView).mainFrame.DOMDocument;
    DOMElement * documentElement = domDocument.documentElement;
    
    NSString * imageWidthString = [documentElement getAttribute:@"width"];
    NSString * imageHeightString = [documentElement getAttribute:@"height"];
    
    NSInteger imageWidth = imageWidthString.integerValue;
    NSInteger imageHeight = imageHeightString.integerValue;
    
    imageWidthString = [NSString stringWithFormat:@"%ld", imageWidth];
    imageHeightString = [NSString stringWithFormat:@"%ld", imageHeight];
    
    self.exportImagesWidthTextField.stringValue = imageWidthString;
    self.exportImagesHeightTextField.stringValue = imageHeightString;
    
    self.exportImagesStartTimeTextField.stringValue = @"0.0";
    self.exportImagesEndTimeTextField.stringValue = @"5.0";
    
    self.exportImagesFramesPerSecondTextField.stringValue = @"30";
    
    [self.exportImagesFormatPopUpButton selectItemWithTitle:@"PNG"];
    [self.exportImagesOutputOptionsPopUpButton selectItemWithTitle:@"Current Image Only"];
    
    [self updateExportImageUI:self];

    [hostWindow beginSheet:self.exportImagesSheet  completionHandler:^(NSModalResponse returnCode)
    {
        if (returnCode == NSModalResponseContinue)
        {
            NSString * outputOptionsString = self.exportImagesOutputOptionsPopUpButton.titleOfSelectedItem;
            
            if ([outputOptionsString isEqualToString:@"Current Image Only"] == YES)
            {
                [self exportImagesLocationWithDefaultName:@"Untitled" toType:@"public.png"]; // kUTTypePNG ?
            }
            else if ([outputOptionsString isEqualToString:@"Animation Images"] == YES)
            {
                [self exportImagesLocationWithDefaultName:@"Untitled" toType:@"public.png"]; // kUTTypePNG ?
            }
            else if ([outputOptionsString isEqualToString:@"iOS .iconset"] == YES)
            {
                [self exportImagesLocationWithDefaultName:@"Untitled" toType:@"public.png"]; // kUTTypePNG ?
            }
            else if ([outputOptionsString isEqualToString:@"macOS .iconset"] == YES)
            {
                [self exportImagesLocationToType:@"public.png"]; // kUTTypePNG ?
            }
        }
    }];
}

//==================================================================================
//	exportImagesButtonAction:
//==================================================================================

- (IBAction) exportImagesButtonAction:(id)sender
{
    [self.window endSheet:self.exportImagesSheet returnCode:NSModalResponseContinue];
    [self.exportImagesSheet orderOut:sender];
}

//==================================================================================
//	cancelExportImagesButtonAction:
//==================================================================================

- (IBAction) cancelExportImagesButtonAction:(id)sender
{
    [self.window endSheet:self.exportImagesSheet returnCode:NSModalResponseCancel];
    [self.exportImagesSheet orderOut:sender];
}

//==================================================================================
//	exportImagesLocationWithDefaultName:toType:
//==================================================================================

- (void)exportImagesLocationWithDefaultName:(NSString*)name toType:(NSString *)typeUTI
{
   // Build a new name for the file using the current name and
   // the filename extension associated with the specified UTI.
   CFStringRef newExtension = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)typeUTI,
                                   kUTTagClassFilenameExtension);
   NSString * newName = [name.stringByDeletingPathExtension
                       stringByAppendingPathExtension:(__bridge NSString*)newExtension];
   CFRelease(newExtension);
 
   // Set the default name for the file and show the panel.
   NSSavePanel*    panel = [NSSavePanel savePanel];
   panel.nameFieldStringValue = newName;
   [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL *  theFile = panel.URL;
 
            // Write the contents in the new format.
            
            NSString * filePath = theFile.path;
            
            self.exportingImagesPathTextField.stringValue = filePath;
            self.exportingImagesWidthTextField.stringValue = self.exportImagesWidthTextField.stringValue;
            self.exportingImagesHeightTextField.stringValue = self.exportImagesHeightTextField.stringValue;
            self.exportingImagesFramesPerSecondTextField.stringValue = self.exportImagesFramesPerSecondTextField.stringValue;
            self.exportingImagesStartTimeTextField.stringValue = self.exportImagesStartTimeTextField.stringValue;
            self.exportingImagesEndTimeTextField.stringValue = self.exportImagesEndTimeTextField.stringValue;
            self.exportingImagesCurrentTimeTextField.stringValue = self.exportImagesStartTimeTextField.stringValue;
        
            self.exportingImagesFormatTextField.stringValue = self.exportImagesFormatPopUpButton.titleOfSelectedItem;
            self.exportingImagesOutputOptionsTextField.stringValue = self.exportImagesOutputOptionsPopUpButton.titleOfSelectedItem;
            if (self.exportImagesAlphaChannelCheckBoxButton.state == YES)
            {
                self.exportingImagesAlphaChannelTextField.stringValue = @"Yes";
            }
            else
            {
                self.exportingImagesAlphaChannelTextField.stringValue = @"No";
            }

            [self.window beginSheet:self.exportingImagesSheet  completionHandler:^(NSModalResponse returnCode)
            {
                if (returnCode == NSModalResponseContinue)
                {
                }
            }];

            [self exportImagesWithPath:filePath];
        }
    }];
}

//==================================================================================
//	exportImagesLocationWithDefaultName:toType:
//==================================================================================

- (void)exportImagesLocationToType:(NSString *)typeUTI
{
    // Use NSOpenPanel to select a directory for output

    NSOpenPanel * panel = [NSOpenPanel openPanel];

    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;
    panel.message = @"Choose a folder for the icon image output files.";
    panel.prompt = @"Save Icon Image Files";

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL *  directoryURL = panel.URL;
 
            // Write the contents in the new format.
            
            NSString * directoryPath = directoryURL.path;
            
            self.exportingImagesPathTextField.stringValue = directoryPath;
            self.exportingImagesWidthTextField.stringValue = self.exportImagesWidthTextField.stringValue;
            self.exportingImagesHeightTextField.stringValue = self.exportImagesHeightTextField.stringValue;
            self.exportingImagesFramesPerSecondTextField.stringValue = self.exportImagesFramesPerSecondTextField.stringValue;
            self.exportingImagesStartTimeTextField.stringValue = self.exportImagesStartTimeTextField.stringValue;
            self.exportingImagesEndTimeTextField.stringValue = self.exportImagesEndTimeTextField.stringValue;
            self.exportingImagesCurrentTimeTextField.stringValue = self.exportImagesStartTimeTextField.stringValue;
        
            self.exportingImagesFormatTextField.stringValue = self.exportImagesFormatPopUpButton.titleOfSelectedItem;
            self.exportingImagesOutputOptionsTextField.stringValue = self.exportImagesOutputOptionsPopUpButton.titleOfSelectedItem;
            if (self.exportImagesAlphaChannelCheckBoxButton.state == YES)
            {
                self.exportingImagesAlphaChannelTextField.stringValue = @"Yes";
            }
            else
            {
                self.exportingImagesAlphaChannelTextField.stringValue = @"No";
            }

            [self.window beginSheet:self.exportingImagesSheet  completionHandler:^(NSModalResponse returnCode)
            {
                if (returnCode == NSModalResponseContinue)
                {
                    //[self exportImagesLocationWithDefaultName:@"Untitled" toType:@"public.png"]; // kUTTypePNG?
                }
            }];

            [self exportImagesWithPath:directoryPath];
        }
    }];
}

//==================================================================================
//	cancelExportingImagesButtonAction:
//==================================================================================

- (IBAction) cancelExportingImagesButtonAction:(id)sender
{
    [self.window endSheet:self.exportingImagesSheet returnCode:NSModalResponseCancel];
    [self.exportingImagesSheet orderOut:sender];
}

//==================================================================================
//	exportingImagesDoneAction:
//==================================================================================

- (IBAction) exportingImagesDoneAction:(id)sender
{
    [self.window endSheet:self.exportingImagesSheet returnCode:NSModalResponseStop];
    [self.exportingImagesSheet orderOut:sender];
}

//==================================================================================
// exportImagesWithPath
//==================================================================================

- (IBAction)exportImagesWithPath:(NSString *)filePath
{
    SVGtoImagesConverter * svgToImagesConverter = [[SVGtoImagesConverter alloc] init];
    svgToImagesConverter.macSVGDocumentWindowController = self;
    
    NSInteger imageWidth = (self.exportImagesWidthTextField.stringValue).integerValue;
    NSInteger imageHeight = (self.exportImagesHeightTextField.stringValue).integerValue;
    
    float startTime = (self.exportImagesStartTimeTextField.stringValue).floatValue;
    float endTime = (self.exportImagesEndTimeTextField.stringValue).floatValue;
    NSInteger framesPerSecond = (self.exportImagesFramesPerSecondTextField.stringValue).integerValue;
    
    if (imageWidth == 0)
    {
        imageWidth = 320;
    }

    if (imageHeight == 0)
    {
        imageHeight = 240;
    }
    
    MacSVGDocument * macSVGDocument = self.document;
    NSString * svgXmlString = [macSVGDocument.svgXmlDocument XMLStringWithOptions:NSXMLNodePreserveCDATA];
    
    NSString * outputFormatString = self.exportingImagesFormatTextField.stringValue;
    NSString * outputOptionsString = self.exportingImagesOutputOptionsTextField.stringValue;
    
    BOOL includeAlpha = NO;
    
    if ([self.exportingImagesAlphaChannelTextField.stringValue isEqualToString:@"Yes"] == YES)
    {
        includeAlpha = YES;
    }

    [svgToImagesConverter writeSVGAnimationAsImages:filePath
            svgXmlString:svgXmlString
            width:imageWidth height:imageHeight
            startTime:startTime endTime:endTime
            framesPerSecond:framesPerSecond
            outputFormat:outputFormatString
            outputOptions:outputOptionsString
            includeAlpha:includeAlpha
            currentTimeTextLabel:self.exportingImagesCurrentTimeTextField
            exportingImagesSheet:self.exportingImagesSheet
            hostWindow:self.window];
}

//==================================================================================
// updateExportImageUI:
//==================================================================================

- (IBAction)updateExportImageUI:(id)sender
{
    NSString * outputOptionsString = self.exportImagesOutputOptionsPopUpButton.titleOfSelectedItem;
    NSString * outputFormatString = self.exportImagesFormatPopUpButton.titleOfSelectedItem;

    DOMDocument * domDocument = (self.svgWebKitController.svgWebView).mainFrame.DOMDocument;
    DOMElement * documentElement = domDocument.documentElement;
    
    NSString * imageWidthString = [documentElement getAttribute:@"width"];
    NSString * imageHeightString = [documentElement getAttribute:@"height"];
    
    NSInteger imageWidth = imageWidthString.integerValue;
    NSInteger imageHeight = imageHeightString.integerValue;
    
    imageWidthString = [NSString stringWithFormat:@"%ld", imageWidth];
    imageHeightString = [NSString stringWithFormat:@"%ld", imageHeight];
    
    BOOL hideStartEndTimes = NO;
    BOOL hideAlpha = NO;
    BOOL sizeIsEditable = YES;
    
    NSString * formatString = self.exportImagesFormatPopUpButton.titleOfSelectedItem;
    
    BOOL includeAlpha = self.exportImagesAlphaChannelCheckBoxButton.state;
    
    // evaluate user options first
    if ([outputOptionsString isEqualToString:@"Current Image Only"] == YES)
    {
        hideStartEndTimes = YES;
    }
    else if ([outputOptionsString isEqualToString:@"Animation Images"] == YES)
    {
        hideStartEndTimes = NO;
    }
    else if ([outputOptionsString isEqualToString:@"macOS .iconset"] == YES)
    {
        hideStartEndTimes = YES;
        hideAlpha = YES;
        includeAlpha = YES;
        sizeIsEditable = NO;
        formatString = @"PNG";
        imageWidthString = @"512";
        imageHeightString = @"512";
    }
    else if ([outputOptionsString isEqualToString:@"iOS .iconset"] == YES)
    {
        hideStartEndTimes = YES;
        hideAlpha = YES;
        includeAlpha = YES;
        sizeIsEditable = NO;
        formatString = @"PNG";
        imageWidthString = @"512";
        imageHeightString = @"512";
    }

    // evaluate user output format after options
    if ([outputFormatString isEqualToString:@"PNG"] == YES)
    {
        hideAlpha = NO;
    }
    else if ([outputFormatString isEqualToString:@"JPEG"] == YES)
    {
        hideAlpha = YES;

        [self.exportImagesAlphaChannelCheckBoxButton setState:NO];
    }
    else if ([outputFormatString isEqualToString:@"TIFF"] == YES)
    {
        hideAlpha = NO;
    }

    self.exportImagesWidthTextField.stringValue = imageWidthString;
    self.exportImagesHeightTextField.stringValue = imageHeightString;
    
    self.exportImagesWidthTextField.editable = sizeIsEditable;
    self.exportImagesHeightTextField.editable = sizeIsEditable;

    self.exportImagesWidthTextField.enabled = sizeIsEditable;
    self.exportImagesHeightTextField.enabled = sizeIsEditable;

    [self.exportImagesFormatPopUpButton selectItemWithTitle:formatString];

    (self.exportImagesStartTimeTextField).hidden = hideStartEndTimes;
    (self.exportImagesStartTimeLabelTextField).hidden = hideStartEndTimes;

    (self.exportImagesEndTimeTextField).hidden = hideStartEndTimes;
    (self.exportImagesEndTimeLabelTextField).hidden = hideStartEndTimes;

    (self.exportImagesFramesPerSecondTextField).hidden = hideStartEndTimes;
    (self.exportImagesFramesPerSecondLabelTextField).hidden = hideStartEndTimes;
    
    (self.exportImagesAlphaChannelCheckBoxButton).hidden = hideAlpha;
    self.exportImagesAlphaChannelCheckBoxButton.state = includeAlpha;
}

//==================================================================================
// generateCoreGraphicsCode:
//==================================================================================

- (IBAction)generateCoreGraphicsCode:(id)sender
{
    NSArray * selectedItems = [self selectedItemsInOutlineView];
    
    NSString * codeString = [svgToCoreGraphicsConverter convertSVGXMLElementsToCoreGraphics:selectedItems];
    #pragma unused(codeString)
}

//==================================================================================
// generateHTML5Video:
//==================================================================================

- (IBAction)generateHTML5Video:(id)sender
{
    NSWindow * hostWindow = self.window;

    DOMDocument * domDocument = (self.svgWebKitController.svgWebView).mainFrame.DOMDocument;
    DOMElement * documentElement = domDocument.documentElement;
    
    NSString * movieWidthString = [documentElement getAttribute:@"width"];
    NSString * movieHeightString = [documentElement getAttribute:@"height"];
    
    NSInteger movieWidth = movieWidthString.integerValue;
    NSInteger movieHeight = movieHeightString.integerValue;
    
    movieWidthString = [NSString stringWithFormat:@"%ld", movieWidth];
    movieHeightString = [NSString stringWithFormat:@"%ld", movieHeight];
    
    self.videoWidthTextField.stringValue = movieWidthString;
    self.videoHeightTextField.stringValue = movieHeightString;
    
    self.videoStartTimeTextField.stringValue = @"0.0";
    self.videoEndTimeTextField.stringValue = @"5.0";
    
    self.videoFramesPerSecondTextField.stringValue = @"30";

    [hostWindow beginSheet:self.generateHTML5VideoSheet  completionHandler:^(NSModalResponse returnCode)
    {
        if (returnCode == NSModalResponseContinue)
        {
            [self saveVideoLocationWithDefaultName:@"Untitled" toType:@"public.mpeg-4"]; // kUTTypeMPEG4
        }
    }];
}

//==================================================================================
//	saveHTML5Video:
//==================================================================================

- (IBAction) saveVideoButtonAction:(id)sender
{
    [self.window endSheet:self.generateHTML5VideoSheet returnCode:NSModalResponseContinue];
    [self.generateHTML5VideoSheet orderOut:sender];
}

//==================================================================================
//	cancelVideoButtonAction:
//==================================================================================

- (IBAction) cancelVideoButtonAction:(id)sender
{
    [self.window endSheet:self.generateHTML5VideoSheet returnCode:NSModalResponseCancel];
    [self.generateHTML5VideoSheet orderOut:sender];
}

//==================================================================================
//	saveLocationWithDefaultName:toType:
//==================================================================================

- (void)saveVideoLocationWithDefaultName:(NSString*)name toType:(NSString *)typeUTI
{
   // Build a new name for the file using the current name and
   // the filename extension associated with the specified UTI.
   CFStringRef newExtension = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)typeUTI,
                                   kUTTagClassFilenameExtension);
   NSString* newName = [name.stringByDeletingPathExtension
                       stringByAppendingPathExtension:(__bridge NSString*)newExtension];
   CFRelease(newExtension);
 
   // Set the default name for the file and show the panel.
   NSSavePanel*    panel = [NSSavePanel savePanel];
   panel.nameFieldStringValue = newName;
   [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
   {
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL *  theFile = panel.URL;
 
            // Write the contents in the new format.
            
            NSString * filePath = theFile.path;
            
            self.generatingVideoPathTextField.stringValue = filePath;
            self.generatingVideoWidthTextField.stringValue = self.videoWidthTextField.stringValue;
            self.generatingVideoHeightTextField.stringValue = self.videoHeightTextField.stringValue;
            self.generatingVideoFramesPerSecondTextField.stringValue = self.videoFramesPerSecondTextField.stringValue;
            self.generatingVideoStartTimeTextField.stringValue = self.videoStartTimeTextField.stringValue;
            self.generatingVideoEndTimeTextField.stringValue = self.videoEndTimeTextField.stringValue;
            self.generatingVideoCurrentTimeTextField.stringValue = self.videoStartTimeTextField.stringValue;

            [self.window beginSheet:self.generatingHTML5VideoSheet  completionHandler:^(NSModalResponse returnCode)
            {
                /*
                if (returnCode == NSModalResponseContinue)
                {
                    [self saveVideoLocationWithDefaultName:@"Untitled" toType:@"public.mpeg-4"]; // kUTTypeMPEG4
                }
                */
                
            }];

            [self exportHTML5Video:filePath];
        }
    }];
}

//==================================================================================
// exportHTML5Video
//==================================================================================

- (IBAction)exportHTML5Video:(NSString *)filePath
{
    SVGtoVideoConverter * svgToVideoConverter = [[SVGtoVideoConverter alloc] init];
    
    NSInteger movieWidth = (self.videoWidthTextField.stringValue).integerValue;
    NSInteger movieHeight = (self.videoHeightTextField.stringValue).integerValue;
    
    float startTime = (self.videoStartTimeTextField.stringValue).floatValue;
    float endTime = (self.videoEndTimeTextField.stringValue).floatValue;
    NSInteger framesPerSecond = (self.videoFramesPerSecondTextField.stringValue).integerValue;
    
    if (movieWidth == 0)
    {
        movieWidth = 320;
    }

    if (movieHeight == 0)
    {
        movieHeight = 240;
    }
    
    MacSVGDocument * macSVGDocument = self.document;
    NSString * svgXmlString = [macSVGDocument.svgXmlDocument XMLStringWithOptions:NSXMLNodePreserveCDATA];

    [svgToVideoConverter writeSVGAnimationAsMovie:filePath
            svgXmlString:svgXmlString
            width:movieWidth height:movieHeight
            startTime:startTime endTime:endTime
            framesPerSecond:framesPerSecond
            currentTimeTextLabel:self.generatingVideoCurrentTimeTextField
            generatingHTML5VideoSheet:self.generatingHTML5VideoSheet
            hostWindow:self.window];
}

// AirDrop methods

- (IBAction)shareWebPreviewURL:(id)sender
{
    NSString * urlString = [self webPreviewURLString];

    NSURL* url = [NSURL URLWithString:urlString];

    NSSharingServicePicker *sharingServicePicker = [[NSSharingServicePicker alloc] initWithItems:[NSArray arrayWithObjects:url, nil]];
    sharingServicePicker.delegate = self;

    [sharingServicePicker showRelativeToRect:[shareWebPreviewURLButton frame]
                                      ofView:shareWebPreviewURLButton
                               preferredEdge:NSMinYEdge];
}


- (NSRect) sharingService: (NSSharingService *) sharingService
sourceFrameOnScreenForShareItem: (id<NSPasteboardWriting>) item
{
    if([item isKindOfClass: [NSURL class]])
    {
        //return a rect from where the image will fly
        return NSZeroRect;
    }

    return NSZeroRect;
}

- (NSImage *) sharingService: (NSSharingService *) sharingService
 transitionImageForShareItem: (id <NSPasteboardWriting>) item
                 contentRect: (NSRect *) contentRect
{
    if([item isKindOfClass: [NSURL class]])
    {

        return [NSImage imageNamed:@"svg-logo.png"];
    }

    return nil;
}

- (id < NSSharingServiceDelegate >)sharingServicePicker:(NSSharingServicePicker *)sharingServicePicker delegateForSharingService:(NSSharingService *)sharingService
{
    return self;
}


@end
