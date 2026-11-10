// GENERATED CODE — DO NOT MODIFY BY HAND

part of 'article.dart';

class ArticleAdapter extends TypeAdapter<Article> {
  @override final int typeId = 0;

  @override
  Article read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{for (int i = 0; i < n; i++) reader.readByte(): reader.read()};
    return Article(
      id: f[0] as String, title: f[1] as String, url: f[2] as String,
      summary: f[3] as String, whyItMatters: f[4] as String,
      source: f[5] as String, type: f[6] as ArticleType,
      publishedAt: f[7] as DateTime, isRead: f[8] as bool,
      isSaved: f[9] as bool, savedAt: f[10] as DateTime?,
      lastReviewedAt: f[11] as DateTime?, topic: f[12] as String,
      estimatedMinutes: f[13] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Article obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.title)
      ..writeByte(2)..write(obj.url)
      ..writeByte(3)..write(obj.summary)
      ..writeByte(4)..write(obj.whyItMatters)
      ..writeByte(5)..write(obj.source)
      ..writeByte(6)..write(obj.type)
      ..writeByte(7)..write(obj.publishedAt)
      ..writeByte(8)..write(obj.isRead)
      ..writeByte(9)..write(obj.isSaved)
      ..writeByte(10)..write(obj.savedAt)
      ..writeByte(11)..write(obj.lastReviewedAt)
      ..writeByte(12)..write(obj.topic)
      ..writeByte(13)..write(obj.estimatedMinutes);
  }

  @override int get hashCode => typeId.hashCode;
  @override bool operator ==(Object o) => o is ArticleAdapter && o.typeId == typeId;
}

class ArticleTypeAdapter extends TypeAdapter<ArticleType> {
  @override final int typeId = 1;

  @override
  ArticleType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0: return ArticleType.rbiCircular;
      case 1: return ArticleType.npciUpdate;
      case 2: return ArticleType.productBlog;
      case 3: return ArticleType.news;
      case 4: return ArticleType.research;
      case 5: return ArticleType.geopolitics;
      case 6: return ArticleType.career;
      default: return ArticleType.news;
    }
  }

  @override
  void write(BinaryWriter writer, ArticleType obj) => writer.writeByte(obj.index);

  @override int get hashCode => typeId.hashCode;
  @override bool operator ==(Object o) => o is ArticleTypeAdapter && o.typeId == typeId;
}
