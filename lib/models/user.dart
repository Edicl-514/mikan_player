class User {
  final int id;
  final String username;
  final String nickname;
  final String? sign;
  final String? url;
  final UserAvatar avatar;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    this.sign,
    this.url,
    required this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      sign: json['sign'] as String?,
      url: json['url'] as String?,
      avatar: UserAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'sign': sign,
      'url': url,
      'avatar': avatar.toJson(),
    };
  }
}

class UserAvatar {
  final String large;
  final String medium;
  final String small;

  UserAvatar({required this.large, required this.medium, required this.small});

  factory UserAvatar.fromJson(Map<String, dynamic> json) {
    return UserAvatar(
      large: json['large'] as String,
      medium: json['medium'] as String,
      small: json['small'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'large': large, 'medium': medium, 'small': small};
  }
}
