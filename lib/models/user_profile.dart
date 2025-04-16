class UserProfile {
  final String uid;
  final String name;
  final String? pfpURL;

  UserProfile({
    required this.uid,
    required this.name,
    this.pfpURL,
  });

  UserProfile.fromJson(Map<String, dynamic> json) 
    : uid = json['uid'] as String,
      name = json['name'] as String,
      pfpURL = json['pfpURL'] as String?;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'pfpURL': pfpURL,
    };
  }
}