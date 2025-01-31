class NotifyModel {
  NotifyModel({
    this.icon,
    this.title,
    this.text,
    this.link,
  });

  NotifyModel.fromJson(dynamic json) {
    icon = json['icon'];
    title = json['title'];
    text = json['text'];
    link = json['link'];
  }

  String? icon;
  String? title;
  String? text;
  String? link;

  NotifyModel copyWith({
    String? icon,
    String? title,
    String? text,
    String? link,
  }) =>
      NotifyModel(
        icon: icon ?? this.icon,
        title: title ?? this.title,
        text: text ?? this.text,
        link: link ?? this.link,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['icon'] = icon;
    map['title'] = title;
    map['text'] = text;
    map['link'] = link;
    return map;
  }

  @override
  String toString() {
    return 'NotifyModel{icon: $icon, title: $title, text: $text, link: $link}';
  }
}
