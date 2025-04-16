class UserProfile {
  final String uid;
  final String name;
  final String? pfpURL;
  final String? email;

  UserProfile({
    required this.uid,
    required this.name,
    this.pfpURL,
    this.email,
  });

  UserProfile.fromJson(Map<String, dynamic> json) 
    : uid = json['uid']?.toString() ?? '',
      name = json['name']?.toString() ?? '',
      pfpURL = json['pfpURL']?.toString(),
      email = json['email']?.toString();

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'pfpURL': pfpURL,
      'email': email,
    };
  }
}