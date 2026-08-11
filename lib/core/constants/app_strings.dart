/// Static strings used throughout the HomeLink app.
class AppStrings {
  AppStrings._();

  // --- App ---
  static const String appName = 'HomeLink';
  static const String appTagline = 'Your Family, Connected Offline';

  // --- Onboarding ---
  static const String welcomeTitle = 'Welcome to HomeLink';
  static const String welcomeSubtitle =
      'Communicate with your family without internet.\nPowered by Wi-Fi Direct.';
  static const String enterName = 'Enter your name';
  static const String nameHint = 'Your name';
  static const String addPhoto = 'Add a profile photo';
  static const String getStarted = 'Get Started';
  static const String generatingId = 'Generating your unique ID...';
  static const String profileCreated = 'Profile created!';
  static const String yourUniqueId = 'Your Unique ID';

  // --- Home ---
  static const String chats = 'Chats';
  static const String calls = 'Calls';
  static const String search = 'Search';
  static const String settings = 'Settings';
  static const String myId = 'My ID';

  // --- Chat ---
  static const String newChat = 'New Chat';
  static const String typeMessage = 'Type a message';
  static const String online = 'Online';
  static const String offline = 'Offline';
  static const String lastSeen = 'Last seen';
  static const String noChats = 'No conversations yet';
  static const String noChatsSubtitle = 'Tap the button below to find\nnearby family members';
  static const String scanning = 'Scanning for nearby devices...';
  static const String noDevicesFound = 'No devices found nearby';
  static const String tapToConnect = 'Tap to connect';
  static const String connecting = 'Connecting...';
  static const String connected = 'Connected';
  static const String disconnected = 'Disconnected';
  static const String messageSent = 'Message sent';
  static const String messageDelivered = 'Delivered';
  static const String messageQueued = 'Queued — will send when online';
  static const String attachment = 'Attachment';
  static const String selectFile = 'Select a file';

  // --- Calls ---
  static const String noCalls = 'No call history';
  static const String noCallsSubtitle = 'Your voice call history\nwill appear here';
  static const String voiceCall = 'Voice Call';
  static const String calling = 'Calling...';
  static const String ringing = 'Ringing...';
  static const String inCall = 'In Call';
  static const String callEnded = 'Call Ended';
  static const String missed = 'Missed';
  static const String incoming = 'Incoming';
  static const String outgoing = 'Outgoing';

  // --- Settings ---
  static const String profile = 'Profile';
  static const String networkStatus = 'Network Status';
  static const String storageUsage = 'Storage Usage';
  static const String about = 'About';
  static const String version = 'Version 1.0.0';
  static const String scanQr = 'Scan QR Code';
  static const String shareId = 'Share your ID';

  // --- Errors ---
  static const String errorGeneric = 'Something went wrong';
  static const String errorConnection = 'Connection failed. Please try again.';
  static const String errorPermission =
      'Permissions required for Wi-Fi Direct communication.';
  static const String errorNameRequired = 'Please enter your name';
}
