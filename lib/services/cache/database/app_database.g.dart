// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DbLocalFavoritesTable extends DbLocalFavorites
    with TableInfo<$DbLocalFavoritesTable, DbLocalFavorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbLocalFavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bangumiIdMeta = const VerificationMeta(
    'bangumiId',
  );
  @override
  late final GeneratedColumn<int> bangumiId = GeneratedColumn<int>(
    'bangumi_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<int> rate = GeneratedColumn<int>(
    'rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _privateMeta = const VerificationMeta(
    'private',
  );
  @override
  late final GeneratedColumn<bool> private = GeneratedColumn<bool>(
    'private',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("private" IN (0, 1))',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseTypeMeta = const VerificationMeta(
    'baseType',
  );
  @override
  late final GeneratedColumn<int> baseType = GeneratedColumn<int>(
    'base_type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseRateMeta = const VerificationMeta(
    'baseRate',
  );
  @override
  late final GeneratedColumn<int> baseRate = GeneratedColumn<int>(
    'base_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseCommentMeta = const VerificationMeta(
    'baseComment',
  );
  @override
  late final GeneratedColumn<String> baseComment = GeneratedColumn<String>(
    'base_comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseTagsJsonMeta = const VerificationMeta(
    'baseTagsJson',
  );
  @override
  late final GeneratedColumn<String> baseTagsJson = GeneratedColumn<String>(
    'base_tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _basePrivateMeta = const VerificationMeta(
    'basePrivate',
  );
  @override
  late final GeneratedColumn<bool> basePrivate = GeneratedColumn<bool>(
    'base_private',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("base_private" IN (0, 1))',
    ),
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<String> remoteUpdatedAt = GeneratedColumn<String>(
    'remote_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerAccountIdMeta = const VerificationMeta(
    'ownerAccountId',
  );
  @override
  late final GeneratedColumn<int> ownerAccountId = GeneratedColumn<int>(
    'owner_account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bangumiId,
    title,
    coverUrl,
    type,
    score,
    createdAt,
    rate,
    comment,
    tagsJson,
    private,
    updatedAt,
    baseType,
    baseRate,
    baseComment,
    baseTagsJson,
    basePrivate,
    remoteUpdatedAt,
    lastSyncedAt,
    ownerAccountId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_local_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbLocalFavorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bangumi_id')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumi_id']!, _bangumiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bangumiIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('private')) {
      context.handle(
        _privateMeta,
        private.isAcceptableOrUnknown(data['private']!, _privateMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('base_type')) {
      context.handle(
        _baseTypeMeta,
        baseType.isAcceptableOrUnknown(data['base_type']!, _baseTypeMeta),
      );
    }
    if (data.containsKey('base_rate')) {
      context.handle(
        _baseRateMeta,
        baseRate.isAcceptableOrUnknown(data['base_rate']!, _baseRateMeta),
      );
    }
    if (data.containsKey('base_comment')) {
      context.handle(
        _baseCommentMeta,
        baseComment.isAcceptableOrUnknown(
          data['base_comment']!,
          _baseCommentMeta,
        ),
      );
    }
    if (data.containsKey('base_tags_json')) {
      context.handle(
        _baseTagsJsonMeta,
        baseTagsJson.isAcceptableOrUnknown(
          data['base_tags_json']!,
          _baseTagsJsonMeta,
        ),
      );
    }
    if (data.containsKey('base_private')) {
      context.handle(
        _basePrivateMeta,
        basePrivate.isAcceptableOrUnknown(
          data['base_private']!,
          _basePrivateMeta,
        ),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('owner_account_id')) {
      context.handle(
        _ownerAccountIdMeta,
        ownerAccountId.isAcceptableOrUnknown(
          data['owner_account_id']!,
          _ownerAccountIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbLocalFavorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbLocalFavorite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bangumi_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      ),
      private: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}private'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
      baseType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_type'],
      ),
      baseRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_rate'],
      ),
      baseComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_comment'],
      ),
      baseTagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_tags_json'],
      ),
      basePrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}base_private'],
      ),
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_updated_at'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      ownerAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}owner_account_id'],
      ),
    );
  }

  @override
  $DbLocalFavoritesTable createAlias(String alias) {
    return $DbLocalFavoritesTable(attachedDatabase, alias);
  }
}

class DbLocalFavorite extends DataClass implements Insertable<DbLocalFavorite> {
  final int id;
  final int bangumiId;
  final String title;
  final String coverUrl;
  final int type;
  final double score;
  final int createdAt;
  final int? rate;
  final String? comment;
  final String? tagsJson;
  final bool? private;

  /// Local last-modified time (ms since epoch) for the metadata above.
  final int? updatedAt;
  final int? baseType;
  final int? baseRate;
  final String? baseComment;
  final String? baseTagsJson;
  final bool? basePrivate;

  /// Server-side ISO timestamp, for display/diagnostics only — never used as a
  /// merge input (clock skew and coarse granularity make it unreliable).
  final String? remoteUpdatedAt;
  final int? lastSyncedAt;

  /// Bangumi account the baseline belongs to. Switching accounts must not let
  /// account A's baseline turn account B's values into "local edits".
  final int? ownerAccountId;
  const DbLocalFavorite({
    required this.id,
    required this.bangumiId,
    required this.title,
    required this.coverUrl,
    required this.type,
    required this.score,
    required this.createdAt,
    this.rate,
    this.comment,
    this.tagsJson,
    this.private,
    this.updatedAt,
    this.baseType,
    this.baseRate,
    this.baseComment,
    this.baseTagsJson,
    this.basePrivate,
    this.remoteUpdatedAt,
    this.lastSyncedAt,
    this.ownerAccountId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bangumi_id'] = Variable<int>(bangumiId);
    map['title'] = Variable<String>(title);
    map['cover_url'] = Variable<String>(coverUrl);
    map['type'] = Variable<int>(type);
    map['score'] = Variable<double>(score);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || rate != null) {
      map['rate'] = Variable<int>(rate);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || tagsJson != null) {
      map['tags_json'] = Variable<String>(tagsJson);
    }
    if (!nullToAbsent || private != null) {
      map['private'] = Variable<bool>(private);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    if (!nullToAbsent || baseType != null) {
      map['base_type'] = Variable<int>(baseType);
    }
    if (!nullToAbsent || baseRate != null) {
      map['base_rate'] = Variable<int>(baseRate);
    }
    if (!nullToAbsent || baseComment != null) {
      map['base_comment'] = Variable<String>(baseComment);
    }
    if (!nullToAbsent || baseTagsJson != null) {
      map['base_tags_json'] = Variable<String>(baseTagsJson);
    }
    if (!nullToAbsent || basePrivate != null) {
      map['base_private'] = Variable<bool>(basePrivate);
    }
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<String>(remoteUpdatedAt);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || ownerAccountId != null) {
      map['owner_account_id'] = Variable<int>(ownerAccountId);
    }
    return map;
  }

  DbLocalFavoritesCompanion toCompanion(bool nullToAbsent) {
    return DbLocalFavoritesCompanion(
      id: Value(id),
      bangumiId: Value(bangumiId),
      title: Value(title),
      coverUrl: Value(coverUrl),
      type: Value(type),
      score: Value(score),
      createdAt: Value(createdAt),
      rate: rate == null && nullToAbsent ? const Value.absent() : Value(rate),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      tagsJson: tagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsJson),
      private: private == null && nullToAbsent
          ? const Value.absent()
          : Value(private),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      baseType: baseType == null && nullToAbsent
          ? const Value.absent()
          : Value(baseType),
      baseRate: baseRate == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRate),
      baseComment: baseComment == null && nullToAbsent
          ? const Value.absent()
          : Value(baseComment),
      baseTagsJson: baseTagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(baseTagsJson),
      basePrivate: basePrivate == null && nullToAbsent
          ? const Value.absent()
          : Value(basePrivate),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      ownerAccountId: ownerAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerAccountId),
    );
  }

  factory DbLocalFavorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbLocalFavorite(
      id: serializer.fromJson<int>(json['id']),
      bangumiId: serializer.fromJson<int>(json['bangumiId']),
      title: serializer.fromJson<String>(json['title']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      type: serializer.fromJson<int>(json['type']),
      score: serializer.fromJson<double>(json['score']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      rate: serializer.fromJson<int?>(json['rate']),
      comment: serializer.fromJson<String?>(json['comment']),
      tagsJson: serializer.fromJson<String?>(json['tagsJson']),
      private: serializer.fromJson<bool?>(json['private']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      baseType: serializer.fromJson<int?>(json['baseType']),
      baseRate: serializer.fromJson<int?>(json['baseRate']),
      baseComment: serializer.fromJson<String?>(json['baseComment']),
      baseTagsJson: serializer.fromJson<String?>(json['baseTagsJson']),
      basePrivate: serializer.fromJson<bool?>(json['basePrivate']),
      remoteUpdatedAt: serializer.fromJson<String?>(json['remoteUpdatedAt']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      ownerAccountId: serializer.fromJson<int?>(json['ownerAccountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bangumiId': serializer.toJson<int>(bangumiId),
      'title': serializer.toJson<String>(title),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'type': serializer.toJson<int>(type),
      'score': serializer.toJson<double>(score),
      'createdAt': serializer.toJson<int>(createdAt),
      'rate': serializer.toJson<int?>(rate),
      'comment': serializer.toJson<String?>(comment),
      'tagsJson': serializer.toJson<String?>(tagsJson),
      'private': serializer.toJson<bool?>(private),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'baseType': serializer.toJson<int?>(baseType),
      'baseRate': serializer.toJson<int?>(baseRate),
      'baseComment': serializer.toJson<String?>(baseComment),
      'baseTagsJson': serializer.toJson<String?>(baseTagsJson),
      'basePrivate': serializer.toJson<bool?>(basePrivate),
      'remoteUpdatedAt': serializer.toJson<String?>(remoteUpdatedAt),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'ownerAccountId': serializer.toJson<int?>(ownerAccountId),
    };
  }

  DbLocalFavorite copyWith({
    int? id,
    int? bangumiId,
    String? title,
    String? coverUrl,
    int? type,
    double? score,
    int? createdAt,
    Value<int?> rate = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    Value<String?> tagsJson = const Value.absent(),
    Value<bool?> private = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
    Value<int?> baseType = const Value.absent(),
    Value<int?> baseRate = const Value.absent(),
    Value<String?> baseComment = const Value.absent(),
    Value<String?> baseTagsJson = const Value.absent(),
    Value<bool?> basePrivate = const Value.absent(),
    Value<String?> remoteUpdatedAt = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<int?> ownerAccountId = const Value.absent(),
  }) => DbLocalFavorite(
    id: id ?? this.id,
    bangumiId: bangumiId ?? this.bangumiId,
    title: title ?? this.title,
    coverUrl: coverUrl ?? this.coverUrl,
    type: type ?? this.type,
    score: score ?? this.score,
    createdAt: createdAt ?? this.createdAt,
    rate: rate.present ? rate.value : this.rate,
    comment: comment.present ? comment.value : this.comment,
    tagsJson: tagsJson.present ? tagsJson.value : this.tagsJson,
    private: private.present ? private.value : this.private,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    baseType: baseType.present ? baseType.value : this.baseType,
    baseRate: baseRate.present ? baseRate.value : this.baseRate,
    baseComment: baseComment.present ? baseComment.value : this.baseComment,
    baseTagsJson: baseTagsJson.present ? baseTagsJson.value : this.baseTagsJson,
    basePrivate: basePrivate.present ? basePrivate.value : this.basePrivate,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    ownerAccountId: ownerAccountId.present
        ? ownerAccountId.value
        : this.ownerAccountId,
  );
  DbLocalFavorite copyWithCompanion(DbLocalFavoritesCompanion data) {
    return DbLocalFavorite(
      id: data.id.present ? data.id.value : this.id,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      title: data.title.present ? data.title.value : this.title,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      type: data.type.present ? data.type.value : this.type,
      score: data.score.present ? data.score.value : this.score,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      rate: data.rate.present ? data.rate.value : this.rate,
      comment: data.comment.present ? data.comment.value : this.comment,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      private: data.private.present ? data.private.value : this.private,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      baseType: data.baseType.present ? data.baseType.value : this.baseType,
      baseRate: data.baseRate.present ? data.baseRate.value : this.baseRate,
      baseComment: data.baseComment.present
          ? data.baseComment.value
          : this.baseComment,
      baseTagsJson: data.baseTagsJson.present
          ? data.baseTagsJson.value
          : this.baseTagsJson,
      basePrivate: data.basePrivate.present
          ? data.basePrivate.value
          : this.basePrivate,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      ownerAccountId: data.ownerAccountId.present
          ? data.ownerAccountId.value
          : this.ownerAccountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbLocalFavorite(')
          ..write('id: $id, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('title: $title, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('type: $type, ')
          ..write('score: $score, ')
          ..write('createdAt: $createdAt, ')
          ..write('rate: $rate, ')
          ..write('comment: $comment, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('private: $private, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('baseType: $baseType, ')
          ..write('baseRate: $baseRate, ')
          ..write('baseComment: $baseComment, ')
          ..write('baseTagsJson: $baseTagsJson, ')
          ..write('basePrivate: $basePrivate, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('ownerAccountId: $ownerAccountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bangumiId,
    title,
    coverUrl,
    type,
    score,
    createdAt,
    rate,
    comment,
    tagsJson,
    private,
    updatedAt,
    baseType,
    baseRate,
    baseComment,
    baseTagsJson,
    basePrivate,
    remoteUpdatedAt,
    lastSyncedAt,
    ownerAccountId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbLocalFavorite &&
          other.id == this.id &&
          other.bangumiId == this.bangumiId &&
          other.title == this.title &&
          other.coverUrl == this.coverUrl &&
          other.type == this.type &&
          other.score == this.score &&
          other.createdAt == this.createdAt &&
          other.rate == this.rate &&
          other.comment == this.comment &&
          other.tagsJson == this.tagsJson &&
          other.private == this.private &&
          other.updatedAt == this.updatedAt &&
          other.baseType == this.baseType &&
          other.baseRate == this.baseRate &&
          other.baseComment == this.baseComment &&
          other.baseTagsJson == this.baseTagsJson &&
          other.basePrivate == this.basePrivate &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.ownerAccountId == this.ownerAccountId);
}

class DbLocalFavoritesCompanion extends UpdateCompanion<DbLocalFavorite> {
  final Value<int> id;
  final Value<int> bangumiId;
  final Value<String> title;
  final Value<String> coverUrl;
  final Value<int> type;
  final Value<double> score;
  final Value<int> createdAt;
  final Value<int?> rate;
  final Value<String?> comment;
  final Value<String?> tagsJson;
  final Value<bool?> private;
  final Value<int?> updatedAt;
  final Value<int?> baseType;
  final Value<int?> baseRate;
  final Value<String?> baseComment;
  final Value<String?> baseTagsJson;
  final Value<bool?> basePrivate;
  final Value<String?> remoteUpdatedAt;
  final Value<int?> lastSyncedAt;
  final Value<int?> ownerAccountId;
  const DbLocalFavoritesCompanion({
    this.id = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.title = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.type = const Value.absent(),
    this.score = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rate = const Value.absent(),
    this.comment = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.private = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.baseType = const Value.absent(),
    this.baseRate = const Value.absent(),
    this.baseComment = const Value.absent(),
    this.baseTagsJson = const Value.absent(),
    this.basePrivate = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.ownerAccountId = const Value.absent(),
  });
  DbLocalFavoritesCompanion.insert({
    this.id = const Value.absent(),
    required int bangumiId,
    required String title,
    required String coverUrl,
    required int type,
    required double score,
    required int createdAt,
    this.rate = const Value.absent(),
    this.comment = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.private = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.baseType = const Value.absent(),
    this.baseRate = const Value.absent(),
    this.baseComment = const Value.absent(),
    this.baseTagsJson = const Value.absent(),
    this.basePrivate = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.ownerAccountId = const Value.absent(),
  }) : bangumiId = Value(bangumiId),
       title = Value(title),
       coverUrl = Value(coverUrl),
       type = Value(type),
       score = Value(score),
       createdAt = Value(createdAt);
  static Insertable<DbLocalFavorite> custom({
    Expression<int>? id,
    Expression<int>? bangumiId,
    Expression<String>? title,
    Expression<String>? coverUrl,
    Expression<int>? type,
    Expression<double>? score,
    Expression<int>? createdAt,
    Expression<int>? rate,
    Expression<String>? comment,
    Expression<String>? tagsJson,
    Expression<bool>? private,
    Expression<int>? updatedAt,
    Expression<int>? baseType,
    Expression<int>? baseRate,
    Expression<String>? baseComment,
    Expression<String>? baseTagsJson,
    Expression<bool>? basePrivate,
    Expression<String>? remoteUpdatedAt,
    Expression<int>? lastSyncedAt,
    Expression<int>? ownerAccountId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bangumiId != null) 'bangumi_id': bangumiId,
      if (title != null) 'title': title,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (type != null) 'type': type,
      if (score != null) 'score': score,
      if (createdAt != null) 'created_at': createdAt,
      if (rate != null) 'rate': rate,
      if (comment != null) 'comment': comment,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (private != null) 'private': private,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (baseType != null) 'base_type': baseType,
      if (baseRate != null) 'base_rate': baseRate,
      if (baseComment != null) 'base_comment': baseComment,
      if (baseTagsJson != null) 'base_tags_json': baseTagsJson,
      if (basePrivate != null) 'base_private': basePrivate,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (ownerAccountId != null) 'owner_account_id': ownerAccountId,
    });
  }

  DbLocalFavoritesCompanion copyWith({
    Value<int>? id,
    Value<int>? bangumiId,
    Value<String>? title,
    Value<String>? coverUrl,
    Value<int>? type,
    Value<double>? score,
    Value<int>? createdAt,
    Value<int?>? rate,
    Value<String?>? comment,
    Value<String?>? tagsJson,
    Value<bool?>? private,
    Value<int?>? updatedAt,
    Value<int?>? baseType,
    Value<int?>? baseRate,
    Value<String?>? baseComment,
    Value<String?>? baseTagsJson,
    Value<bool?>? basePrivate,
    Value<String?>? remoteUpdatedAt,
    Value<int?>? lastSyncedAt,
    Value<int?>? ownerAccountId,
  }) {
    return DbLocalFavoritesCompanion(
      id: id ?? this.id,
      bangumiId: bangumiId ?? this.bangumiId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      type: type ?? this.type,
      score: score ?? this.score,
      createdAt: createdAt ?? this.createdAt,
      rate: rate ?? this.rate,
      comment: comment ?? this.comment,
      tagsJson: tagsJson ?? this.tagsJson,
      private: private ?? this.private,
      updatedAt: updatedAt ?? this.updatedAt,
      baseType: baseType ?? this.baseType,
      baseRate: baseRate ?? this.baseRate,
      baseComment: baseComment ?? this.baseComment,
      baseTagsJson: baseTagsJson ?? this.baseTagsJson,
      basePrivate: basePrivate ?? this.basePrivate,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      ownerAccountId: ownerAccountId ?? this.ownerAccountId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bangumiId.present) {
      map['bangumi_id'] = Variable<int>(bangumiId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rate.present) {
      map['rate'] = Variable<int>(rate.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (private.present) {
      map['private'] = Variable<bool>(private.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (baseType.present) {
      map['base_type'] = Variable<int>(baseType.value);
    }
    if (baseRate.present) {
      map['base_rate'] = Variable<int>(baseRate.value);
    }
    if (baseComment.present) {
      map['base_comment'] = Variable<String>(baseComment.value);
    }
    if (baseTagsJson.present) {
      map['base_tags_json'] = Variable<String>(baseTagsJson.value);
    }
    if (basePrivate.present) {
      map['base_private'] = Variable<bool>(basePrivate.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<String>(remoteUpdatedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (ownerAccountId.present) {
      map['owner_account_id'] = Variable<int>(ownerAccountId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbLocalFavoritesCompanion(')
          ..write('id: $id, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('title: $title, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('type: $type, ')
          ..write('score: $score, ')
          ..write('createdAt: $createdAt, ')
          ..write('rate: $rate, ')
          ..write('comment: $comment, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('private: $private, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('baseType: $baseType, ')
          ..write('baseRate: $baseRate, ')
          ..write('baseComment: $baseComment, ')
          ..write('baseTagsJson: $baseTagsJson, ')
          ..write('basePrivate: $basePrivate, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('ownerAccountId: $ownerAccountId')
          ..write(')'))
        .toString();
  }
}

class $DbBangumiSyncQueueTable extends DbBangumiSyncQueue
    with TableInfo<$DbBangumiSyncQueueTable, DbBangumiSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbBangumiSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baselineJsonMeta = const VerificationMeta(
    'baselineJson',
  );
  @override
  late final GeneratedColumn<String> baselineJson = GeneratedColumn<String>(
    'baseline_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    subjectId,
    operation,
    payloadJson,
    baselineJson,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_bangumi_sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBangumiSyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('baseline_json')) {
      context.handle(
        _baselineJsonMeta,
        baselineJson.isAcceptableOrUnknown(
          data['baseline_json']!,
          _baselineJsonMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, subjectId, operation},
  ];
  @override
  DbBangumiSyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBangumiSyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      baselineJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline_json'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DbBangumiSyncQueueTable createAlias(String alias) {
    return $DbBangumiSyncQueueTable(attachedDatabase, alias);
  }
}

class DbBangumiSyncQueueData extends DataClass
    implements Insertable<DbBangumiSyncQueueData> {
  final int id;

  /// Bangumi user id. Tasks are never sent under a different account, and are
  /// deleted on logout / account switch.
  final int accountId;
  final int subjectId;

  /// `status` | `metadata` | `delete`.
  final String operation;

  /// Field-level payload. Must distinguish "leave unchanged" from "clear", so
  /// presence is encoded explicitly rather than by key omission.
  final String payloadJson;

  /// Baseline captured at enqueue time, so a replay can tell whether the remote
  /// side was changed by someone else in the meantime.
  final String? baselineJson;
  final int attemptCount;
  final int nextAttemptAt;
  final String? lastError;
  final int createdAt;
  final int updatedAt;
  const DbBangumiSyncQueueData({
    required this.id,
    required this.accountId,
    required this.subjectId,
    required this.operation,
    required this.payloadJson,
    this.baselineJson,
    required this.attemptCount,
    required this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['subject_id'] = Variable<int>(subjectId);
    map['operation'] = Variable<String>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || baselineJson != null) {
      map['baseline_json'] = Variable<String>(baselineJson);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DbBangumiSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return DbBangumiSyncQueueCompanion(
      id: Value(id),
      accountId: Value(accountId),
      subjectId: Value(subjectId),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      baselineJson: baselineJson == null && nullToAbsent
          ? const Value.absent()
          : Value(baselineJson),
      attemptCount: Value(attemptCount),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbBangumiSyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBangumiSyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      baselineJson: serializer.fromJson<String?>(json['baselineJson']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<int>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'subjectId': serializer.toJson<int>(subjectId),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'baselineJson': serializer.toJson<String?>(baselineJson),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<int>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DbBangumiSyncQueueData copyWith({
    int? id,
    int? accountId,
    int? subjectId,
    String? operation,
    String? payloadJson,
    Value<String?> baselineJson = const Value.absent(),
    int? attemptCount,
    int? nextAttemptAt,
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => DbBangumiSyncQueueData(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    subjectId: subjectId ?? this.subjectId,
    operation: operation ?? this.operation,
    payloadJson: payloadJson ?? this.payloadJson,
    baselineJson: baselineJson.present ? baselineJson.value : this.baselineJson,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbBangumiSyncQueueData copyWithCompanion(DbBangumiSyncQueueCompanion data) {
    return DbBangumiSyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      baselineJson: data.baselineJson.present
          ? data.baselineJson.value
          : this.baselineJson,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiSyncQueueData(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('subjectId: $subjectId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baselineJson: $baselineJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    subjectId,
    operation,
    payloadJson,
    baselineJson,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBangumiSyncQueueData &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.subjectId == this.subjectId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.baselineJson == this.baselineJson &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DbBangumiSyncQueueCompanion
    extends UpdateCompanion<DbBangumiSyncQueueData> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> subjectId;
  final Value<String> operation;
  final Value<String> payloadJson;
  final Value<String?> baselineJson;
  final Value<int> attemptCount;
  final Value<int> nextAttemptAt;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const DbBangumiSyncQueueCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.baselineJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DbBangumiSyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required int subjectId,
    required String operation,
    required String payloadJson,
    this.baselineJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : accountId = Value(accountId),
       subjectId = Value(subjectId),
       operation = Value(operation),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DbBangumiSyncQueueData> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? subjectId,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<String>? baselineJson,
    Expression<int>? attemptCount,
    Expression<int>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (subjectId != null) 'subject_id': subjectId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (baselineJson != null) 'baseline_json': baselineJson,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DbBangumiSyncQueueCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int>? subjectId,
    Value<String>? operation,
    Value<String>? payloadJson,
    Value<String?>? baselineJson,
    Value<int>? attemptCount,
    Value<int>? nextAttemptAt,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return DbBangumiSyncQueueCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      subjectId: subjectId ?? this.subjectId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      baselineJson: baselineJson ?? this.baselineJson,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (baselineJson.present) {
      map['baseline_json'] = Variable<String>(baselineJson.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiSyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('subjectId: $subjectId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baselineJson: $baselineJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DbBangumiSubjectCachesTable extends DbBangumiSubjectCaches
    with TableInfo<$DbBangumiSubjectCachesTable, DbBangumiSubjectCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbBangumiSubjectCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bangumiIdMeta = const VerificationMeta(
    'bangumiId',
  );
  @override
  late final GeneratedColumn<int> bangumiId = GeneratedColumn<int>(
    'bangumi_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleCnMeta = const VerificationMeta(
    'titleCn',
  );
  @override
  late final GeneratedColumn<String> titleCn = GeneratedColumn<String>(
    'title_cn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalTitleMeta = const VerificationMeta(
    'originalTitle',
  );
  @override
  late final GeneratedColumn<String> originalTitle = GeneratedColumn<String>(
    'original_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageSmallMeta = const VerificationMeta(
    'imageSmall',
  );
  @override
  late final GeneratedColumn<String> imageSmall = GeneratedColumn<String>(
    'image_small',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageGridMeta = const VerificationMeta(
    'imageGrid',
  );
  @override
  late final GeneratedColumn<String> imageGrid = GeneratedColumn<String>(
    'image_grid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageLargeMeta = const VerificationMeta(
    'imageLarge',
  );
  @override
  late final GeneratedColumn<String> imageLarge = GeneratedColumn<String>(
    'image_large',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageMediumMeta = const VerificationMeta(
    'imageMedium',
  );
  @override
  late final GeneratedColumn<String> imageMedium = GeneratedColumn<String>(
    'image_medium',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageCommonMeta = const VerificationMeta(
    'imageCommon',
  );
  @override
  late final GeneratedColumn<String> imageCommon = GeneratedColumn<String>(
    'image_common',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localImagePathMeta = const VerificationMeta(
    'localImagePath',
  );
  @override
  late final GeneratedColumn<String> localImagePath = GeneratedColumn<String>(
    'local_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<String> airDate = GeneratedColumn<String>(
    'air_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airWeekdayMeta = const VerificationMeta(
    'airWeekday',
  );
  @override
  late final GeneratedColumn<String> airWeekday = GeneratedColumn<String>(
    'air_weekday',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fullJsonMeta = const VerificationMeta(
    'fullJson',
  );
  @override
  late final GeneratedColumn<String> fullJson = GeneratedColumn<String>(
    'full_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalEpisodesMeta = const VerificationMeta(
    'totalEpisodes',
  );
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
    'total_episodes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bangumiId,
    title,
    titleCn,
    originalTitle,
    description,
    score,
    rank,
    imageSmall,
    imageGrid,
    imageLarge,
    imageMedium,
    imageCommon,
    localImagePath,
    airDate,
    airWeekday,
    tagsJson,
    fullJson,
    type,
    totalEpisodes,
    cachedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_bangumi_subject_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBangumiSubjectCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bangumi_id')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumi_id']!, _bangumiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bangumiIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_cn')) {
      context.handle(
        _titleCnMeta,
        titleCn.isAcceptableOrUnknown(data['title_cn']!, _titleCnMeta),
      );
    }
    if (data.containsKey('original_title')) {
      context.handle(
        _originalTitleMeta,
        originalTitle.isAcceptableOrUnknown(
          data['original_title']!,
          _originalTitleMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    }
    if (data.containsKey('image_small')) {
      context.handle(
        _imageSmallMeta,
        imageSmall.isAcceptableOrUnknown(data['image_small']!, _imageSmallMeta),
      );
    }
    if (data.containsKey('image_grid')) {
      context.handle(
        _imageGridMeta,
        imageGrid.isAcceptableOrUnknown(data['image_grid']!, _imageGridMeta),
      );
    }
    if (data.containsKey('image_large')) {
      context.handle(
        _imageLargeMeta,
        imageLarge.isAcceptableOrUnknown(data['image_large']!, _imageLargeMeta),
      );
    }
    if (data.containsKey('image_medium')) {
      context.handle(
        _imageMediumMeta,
        imageMedium.isAcceptableOrUnknown(
          data['image_medium']!,
          _imageMediumMeta,
        ),
      );
    }
    if (data.containsKey('image_common')) {
      context.handle(
        _imageCommonMeta,
        imageCommon.isAcceptableOrUnknown(
          data['image_common']!,
          _imageCommonMeta,
        ),
      );
    }
    if (data.containsKey('local_image_path')) {
      context.handle(
        _localImagePathMeta,
        localImagePath.isAcceptableOrUnknown(
          data['local_image_path']!,
          _localImagePathMeta,
        ),
      );
    }
    if (data.containsKey('air_date')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['air_date']!, _airDateMeta),
      );
    }
    if (data.containsKey('air_weekday')) {
      context.handle(
        _airWeekdayMeta,
        airWeekday.isAcceptableOrUnknown(data['air_weekday']!, _airWeekdayMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('full_json')) {
      context.handle(
        _fullJsonMeta,
        fullJson.isAcceptableOrUnknown(data['full_json']!, _fullJsonMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('total_episodes')) {
      context.handle(
        _totalEpisodesMeta,
        totalEpisodes.isAcceptableOrUnknown(
          data['total_episodes']!,
          _totalEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBangumiSubjectCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBangumiSubjectCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bangumi_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleCn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_cn'],
      ),
      originalTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_title'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      ),
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      ),
      imageSmall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_small'],
      ),
      imageGrid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_grid'],
      ),
      imageLarge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_large'],
      ),
      imageMedium: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_medium'],
      ),
      imageCommon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_common'],
      ),
      localImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_image_path'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}air_date'],
      ),
      airWeekday: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}air_weekday'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      ),
      fullJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_json'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      ),
      totalEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_episodes'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $DbBangumiSubjectCachesTable createAlias(String alias) {
    return $DbBangumiSubjectCachesTable(attachedDatabase, alias);
  }
}

class DbBangumiSubjectCache extends DataClass
    implements Insertable<DbBangumiSubjectCache> {
  final int id;
  final int bangumiId;
  final String title;
  final String? titleCn;
  final String? originalTitle;
  final String? description;
  final double? score;
  final int? rank;
  final String? imageSmall;
  final String? imageGrid;
  final String? imageLarge;
  final String? imageMedium;
  final String? imageCommon;
  final String? localImagePath;
  final String? airDate;
  final String? airWeekday;
  final String? tagsJson;
  final String? fullJson;
  final int? type;
  final int? totalEpisodes;
  final int cachedAt;
  final int expiresAt;
  const DbBangumiSubjectCache({
    required this.id,
    required this.bangumiId,
    required this.title,
    this.titleCn,
    this.originalTitle,
    this.description,
    this.score,
    this.rank,
    this.imageSmall,
    this.imageGrid,
    this.imageLarge,
    this.imageMedium,
    this.imageCommon,
    this.localImagePath,
    this.airDate,
    this.airWeekday,
    this.tagsJson,
    this.fullJson,
    this.type,
    this.totalEpisodes,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bangumi_id'] = Variable<int>(bangumiId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || titleCn != null) {
      map['title_cn'] = Variable<String>(titleCn);
    }
    if (!nullToAbsent || originalTitle != null) {
      map['original_title'] = Variable<String>(originalTitle);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    if (!nullToAbsent || rank != null) {
      map['rank'] = Variable<int>(rank);
    }
    if (!nullToAbsent || imageSmall != null) {
      map['image_small'] = Variable<String>(imageSmall);
    }
    if (!nullToAbsent || imageGrid != null) {
      map['image_grid'] = Variable<String>(imageGrid);
    }
    if (!nullToAbsent || imageLarge != null) {
      map['image_large'] = Variable<String>(imageLarge);
    }
    if (!nullToAbsent || imageMedium != null) {
      map['image_medium'] = Variable<String>(imageMedium);
    }
    if (!nullToAbsent || imageCommon != null) {
      map['image_common'] = Variable<String>(imageCommon);
    }
    if (!nullToAbsent || localImagePath != null) {
      map['local_image_path'] = Variable<String>(localImagePath);
    }
    if (!nullToAbsent || airDate != null) {
      map['air_date'] = Variable<String>(airDate);
    }
    if (!nullToAbsent || airWeekday != null) {
      map['air_weekday'] = Variable<String>(airWeekday);
    }
    if (!nullToAbsent || tagsJson != null) {
      map['tags_json'] = Variable<String>(tagsJson);
    }
    if (!nullToAbsent || fullJson != null) {
      map['full_json'] = Variable<String>(fullJson);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<int>(type);
    }
    if (!nullToAbsent || totalEpisodes != null) {
      map['total_episodes'] = Variable<int>(totalEpisodes);
    }
    map['cached_at'] = Variable<int>(cachedAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  DbBangumiSubjectCachesCompanion toCompanion(bool nullToAbsent) {
    return DbBangumiSubjectCachesCompanion(
      id: Value(id),
      bangumiId: Value(bangumiId),
      title: Value(title),
      titleCn: titleCn == null && nullToAbsent
          ? const Value.absent()
          : Value(titleCn),
      originalTitle: originalTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(originalTitle),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      rank: rank == null && nullToAbsent ? const Value.absent() : Value(rank),
      imageSmall: imageSmall == null && nullToAbsent
          ? const Value.absent()
          : Value(imageSmall),
      imageGrid: imageGrid == null && nullToAbsent
          ? const Value.absent()
          : Value(imageGrid),
      imageLarge: imageLarge == null && nullToAbsent
          ? const Value.absent()
          : Value(imageLarge),
      imageMedium: imageMedium == null && nullToAbsent
          ? const Value.absent()
          : Value(imageMedium),
      imageCommon: imageCommon == null && nullToAbsent
          ? const Value.absent()
          : Value(imageCommon),
      localImagePath: localImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localImagePath),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
      airWeekday: airWeekday == null && nullToAbsent
          ? const Value.absent()
          : Value(airWeekday),
      tagsJson: tagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsJson),
      fullJson: fullJson == null && nullToAbsent
          ? const Value.absent()
          : Value(fullJson),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      totalEpisodes: totalEpisodes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEpisodes),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DbBangumiSubjectCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBangumiSubjectCache(
      id: serializer.fromJson<int>(json['id']),
      bangumiId: serializer.fromJson<int>(json['bangumiId']),
      title: serializer.fromJson<String>(json['title']),
      titleCn: serializer.fromJson<String?>(json['titleCn']),
      originalTitle: serializer.fromJson<String?>(json['originalTitle']),
      description: serializer.fromJson<String?>(json['description']),
      score: serializer.fromJson<double?>(json['score']),
      rank: serializer.fromJson<int?>(json['rank']),
      imageSmall: serializer.fromJson<String?>(json['imageSmall']),
      imageGrid: serializer.fromJson<String?>(json['imageGrid']),
      imageLarge: serializer.fromJson<String?>(json['imageLarge']),
      imageMedium: serializer.fromJson<String?>(json['imageMedium']),
      imageCommon: serializer.fromJson<String?>(json['imageCommon']),
      localImagePath: serializer.fromJson<String?>(json['localImagePath']),
      airDate: serializer.fromJson<String?>(json['airDate']),
      airWeekday: serializer.fromJson<String?>(json['airWeekday']),
      tagsJson: serializer.fromJson<String?>(json['tagsJson']),
      fullJson: serializer.fromJson<String?>(json['fullJson']),
      type: serializer.fromJson<int?>(json['type']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bangumiId': serializer.toJson<int>(bangumiId),
      'title': serializer.toJson<String>(title),
      'titleCn': serializer.toJson<String?>(titleCn),
      'originalTitle': serializer.toJson<String?>(originalTitle),
      'description': serializer.toJson<String?>(description),
      'score': serializer.toJson<double?>(score),
      'rank': serializer.toJson<int?>(rank),
      'imageSmall': serializer.toJson<String?>(imageSmall),
      'imageGrid': serializer.toJson<String?>(imageGrid),
      'imageLarge': serializer.toJson<String?>(imageLarge),
      'imageMedium': serializer.toJson<String?>(imageMedium),
      'imageCommon': serializer.toJson<String?>(imageCommon),
      'localImagePath': serializer.toJson<String?>(localImagePath),
      'airDate': serializer.toJson<String?>(airDate),
      'airWeekday': serializer.toJson<String?>(airWeekday),
      'tagsJson': serializer.toJson<String?>(tagsJson),
      'fullJson': serializer.toJson<String?>(fullJson),
      'type': serializer.toJson<int?>(type),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  DbBangumiSubjectCache copyWith({
    int? id,
    int? bangumiId,
    String? title,
    Value<String?> titleCn = const Value.absent(),
    Value<String?> originalTitle = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<double?> score = const Value.absent(),
    Value<int?> rank = const Value.absent(),
    Value<String?> imageSmall = const Value.absent(),
    Value<String?> imageGrid = const Value.absent(),
    Value<String?> imageLarge = const Value.absent(),
    Value<String?> imageMedium = const Value.absent(),
    Value<String?> imageCommon = const Value.absent(),
    Value<String?> localImagePath = const Value.absent(),
    Value<String?> airDate = const Value.absent(),
    Value<String?> airWeekday = const Value.absent(),
    Value<String?> tagsJson = const Value.absent(),
    Value<String?> fullJson = const Value.absent(),
    Value<int?> type = const Value.absent(),
    Value<int?> totalEpisodes = const Value.absent(),
    int? cachedAt,
    int? expiresAt,
  }) => DbBangumiSubjectCache(
    id: id ?? this.id,
    bangumiId: bangumiId ?? this.bangumiId,
    title: title ?? this.title,
    titleCn: titleCn.present ? titleCn.value : this.titleCn,
    originalTitle: originalTitle.present
        ? originalTitle.value
        : this.originalTitle,
    description: description.present ? description.value : this.description,
    score: score.present ? score.value : this.score,
    rank: rank.present ? rank.value : this.rank,
    imageSmall: imageSmall.present ? imageSmall.value : this.imageSmall,
    imageGrid: imageGrid.present ? imageGrid.value : this.imageGrid,
    imageLarge: imageLarge.present ? imageLarge.value : this.imageLarge,
    imageMedium: imageMedium.present ? imageMedium.value : this.imageMedium,
    imageCommon: imageCommon.present ? imageCommon.value : this.imageCommon,
    localImagePath: localImagePath.present
        ? localImagePath.value
        : this.localImagePath,
    airDate: airDate.present ? airDate.value : this.airDate,
    airWeekday: airWeekday.present ? airWeekday.value : this.airWeekday,
    tagsJson: tagsJson.present ? tagsJson.value : this.tagsJson,
    fullJson: fullJson.present ? fullJson.value : this.fullJson,
    type: type.present ? type.value : this.type,
    totalEpisodes: totalEpisodes.present
        ? totalEpisodes.value
        : this.totalEpisodes,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  DbBangumiSubjectCache copyWithCompanion(
    DbBangumiSubjectCachesCompanion data,
  ) {
    return DbBangumiSubjectCache(
      id: data.id.present ? data.id.value : this.id,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      title: data.title.present ? data.title.value : this.title,
      titleCn: data.titleCn.present ? data.titleCn.value : this.titleCn,
      originalTitle: data.originalTitle.present
          ? data.originalTitle.value
          : this.originalTitle,
      description: data.description.present
          ? data.description.value
          : this.description,
      score: data.score.present ? data.score.value : this.score,
      rank: data.rank.present ? data.rank.value : this.rank,
      imageSmall: data.imageSmall.present
          ? data.imageSmall.value
          : this.imageSmall,
      imageGrid: data.imageGrid.present ? data.imageGrid.value : this.imageGrid,
      imageLarge: data.imageLarge.present
          ? data.imageLarge.value
          : this.imageLarge,
      imageMedium: data.imageMedium.present
          ? data.imageMedium.value
          : this.imageMedium,
      imageCommon: data.imageCommon.present
          ? data.imageCommon.value
          : this.imageCommon,
      localImagePath: data.localImagePath.present
          ? data.localImagePath.value
          : this.localImagePath,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
      airWeekday: data.airWeekday.present
          ? data.airWeekday.value
          : this.airWeekday,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      fullJson: data.fullJson.present ? data.fullJson.value : this.fullJson,
      type: data.type.present ? data.type.value : this.type,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiSubjectCache(')
          ..write('id: $id, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('title: $title, ')
          ..write('titleCn: $titleCn, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('description: $description, ')
          ..write('score: $score, ')
          ..write('rank: $rank, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageGrid: $imageGrid, ')
          ..write('imageLarge: $imageLarge, ')
          ..write('imageMedium: $imageMedium, ')
          ..write('imageCommon: $imageCommon, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('airDate: $airDate, ')
          ..write('airWeekday: $airWeekday, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('fullJson: $fullJson, ')
          ..write('type: $type, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    bangumiId,
    title,
    titleCn,
    originalTitle,
    description,
    score,
    rank,
    imageSmall,
    imageGrid,
    imageLarge,
    imageMedium,
    imageCommon,
    localImagePath,
    airDate,
    airWeekday,
    tagsJson,
    fullJson,
    type,
    totalEpisodes,
    cachedAt,
    expiresAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBangumiSubjectCache &&
          other.id == this.id &&
          other.bangumiId == this.bangumiId &&
          other.title == this.title &&
          other.titleCn == this.titleCn &&
          other.originalTitle == this.originalTitle &&
          other.description == this.description &&
          other.score == this.score &&
          other.rank == this.rank &&
          other.imageSmall == this.imageSmall &&
          other.imageGrid == this.imageGrid &&
          other.imageLarge == this.imageLarge &&
          other.imageMedium == this.imageMedium &&
          other.imageCommon == this.imageCommon &&
          other.localImagePath == this.localImagePath &&
          other.airDate == this.airDate &&
          other.airWeekday == this.airWeekday &&
          other.tagsJson == this.tagsJson &&
          other.fullJson == this.fullJson &&
          other.type == this.type &&
          other.totalEpisodes == this.totalEpisodes &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class DbBangumiSubjectCachesCompanion
    extends UpdateCompanion<DbBangumiSubjectCache> {
  final Value<int> id;
  final Value<int> bangumiId;
  final Value<String> title;
  final Value<String?> titleCn;
  final Value<String?> originalTitle;
  final Value<String?> description;
  final Value<double?> score;
  final Value<int?> rank;
  final Value<String?> imageSmall;
  final Value<String?> imageGrid;
  final Value<String?> imageLarge;
  final Value<String?> imageMedium;
  final Value<String?> imageCommon;
  final Value<String?> localImagePath;
  final Value<String?> airDate;
  final Value<String?> airWeekday;
  final Value<String?> tagsJson;
  final Value<String?> fullJson;
  final Value<int?> type;
  final Value<int?> totalEpisodes;
  final Value<int> cachedAt;
  final Value<int> expiresAt;
  const DbBangumiSubjectCachesCompanion({
    this.id = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.title = const Value.absent(),
    this.titleCn = const Value.absent(),
    this.originalTitle = const Value.absent(),
    this.description = const Value.absent(),
    this.score = const Value.absent(),
    this.rank = const Value.absent(),
    this.imageSmall = const Value.absent(),
    this.imageGrid = const Value.absent(),
    this.imageLarge = const Value.absent(),
    this.imageMedium = const Value.absent(),
    this.imageCommon = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.airDate = const Value.absent(),
    this.airWeekday = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.fullJson = const Value.absent(),
    this.type = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  DbBangumiSubjectCachesCompanion.insert({
    this.id = const Value.absent(),
    required int bangumiId,
    required String title,
    this.titleCn = const Value.absent(),
    this.originalTitle = const Value.absent(),
    this.description = const Value.absent(),
    this.score = const Value.absent(),
    this.rank = const Value.absent(),
    this.imageSmall = const Value.absent(),
    this.imageGrid = const Value.absent(),
    this.imageLarge = const Value.absent(),
    this.imageMedium = const Value.absent(),
    this.imageCommon = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.airDate = const Value.absent(),
    this.airWeekday = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.fullJson = const Value.absent(),
    this.type = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    required int cachedAt,
    required int expiresAt,
  }) : bangumiId = Value(bangumiId),
       title = Value(title),
       cachedAt = Value(cachedAt),
       expiresAt = Value(expiresAt);
  static Insertable<DbBangumiSubjectCache> custom({
    Expression<int>? id,
    Expression<int>? bangumiId,
    Expression<String>? title,
    Expression<String>? titleCn,
    Expression<String>? originalTitle,
    Expression<String>? description,
    Expression<double>? score,
    Expression<int>? rank,
    Expression<String>? imageSmall,
    Expression<String>? imageGrid,
    Expression<String>? imageLarge,
    Expression<String>? imageMedium,
    Expression<String>? imageCommon,
    Expression<String>? localImagePath,
    Expression<String>? airDate,
    Expression<String>? airWeekday,
    Expression<String>? tagsJson,
    Expression<String>? fullJson,
    Expression<int>? type,
    Expression<int>? totalEpisodes,
    Expression<int>? cachedAt,
    Expression<int>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bangumiId != null) 'bangumi_id': bangumiId,
      if (title != null) 'title': title,
      if (titleCn != null) 'title_cn': titleCn,
      if (originalTitle != null) 'original_title': originalTitle,
      if (description != null) 'description': description,
      if (score != null) 'score': score,
      if (rank != null) 'rank': rank,
      if (imageSmall != null) 'image_small': imageSmall,
      if (imageGrid != null) 'image_grid': imageGrid,
      if (imageLarge != null) 'image_large': imageLarge,
      if (imageMedium != null) 'image_medium': imageMedium,
      if (imageCommon != null) 'image_common': imageCommon,
      if (localImagePath != null) 'local_image_path': localImagePath,
      if (airDate != null) 'air_date': airDate,
      if (airWeekday != null) 'air_weekday': airWeekday,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (fullJson != null) 'full_json': fullJson,
      if (type != null) 'type': type,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  DbBangumiSubjectCachesCompanion copyWith({
    Value<int>? id,
    Value<int>? bangumiId,
    Value<String>? title,
    Value<String?>? titleCn,
    Value<String?>? originalTitle,
    Value<String?>? description,
    Value<double?>? score,
    Value<int?>? rank,
    Value<String?>? imageSmall,
    Value<String?>? imageGrid,
    Value<String?>? imageLarge,
    Value<String?>? imageMedium,
    Value<String?>? imageCommon,
    Value<String?>? localImagePath,
    Value<String?>? airDate,
    Value<String?>? airWeekday,
    Value<String?>? tagsJson,
    Value<String?>? fullJson,
    Value<int?>? type,
    Value<int?>? totalEpisodes,
    Value<int>? cachedAt,
    Value<int>? expiresAt,
  }) {
    return DbBangumiSubjectCachesCompanion(
      id: id ?? this.id,
      bangumiId: bangumiId ?? this.bangumiId,
      title: title ?? this.title,
      titleCn: titleCn ?? this.titleCn,
      originalTitle: originalTitle ?? this.originalTitle,
      description: description ?? this.description,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      imageSmall: imageSmall ?? this.imageSmall,
      imageGrid: imageGrid ?? this.imageGrid,
      imageLarge: imageLarge ?? this.imageLarge,
      imageMedium: imageMedium ?? this.imageMedium,
      imageCommon: imageCommon ?? this.imageCommon,
      localImagePath: localImagePath ?? this.localImagePath,
      airDate: airDate ?? this.airDate,
      airWeekday: airWeekday ?? this.airWeekday,
      tagsJson: tagsJson ?? this.tagsJson,
      fullJson: fullJson ?? this.fullJson,
      type: type ?? this.type,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bangumiId.present) {
      map['bangumi_id'] = Variable<int>(bangumiId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleCn.present) {
      map['title_cn'] = Variable<String>(titleCn.value);
    }
    if (originalTitle.present) {
      map['original_title'] = Variable<String>(originalTitle.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (imageSmall.present) {
      map['image_small'] = Variable<String>(imageSmall.value);
    }
    if (imageGrid.present) {
      map['image_grid'] = Variable<String>(imageGrid.value);
    }
    if (imageLarge.present) {
      map['image_large'] = Variable<String>(imageLarge.value);
    }
    if (imageMedium.present) {
      map['image_medium'] = Variable<String>(imageMedium.value);
    }
    if (imageCommon.present) {
      map['image_common'] = Variable<String>(imageCommon.value);
    }
    if (localImagePath.present) {
      map['local_image_path'] = Variable<String>(localImagePath.value);
    }
    if (airDate.present) {
      map['air_date'] = Variable<String>(airDate.value);
    }
    if (airWeekday.present) {
      map['air_weekday'] = Variable<String>(airWeekday.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (fullJson.present) {
      map['full_json'] = Variable<String>(fullJson.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (totalEpisodes.present) {
      map['total_episodes'] = Variable<int>(totalEpisodes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiSubjectCachesCompanion(')
          ..write('id: $id, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('title: $title, ')
          ..write('titleCn: $titleCn, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('description: $description, ')
          ..write('score: $score, ')
          ..write('rank: $rank, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageGrid: $imageGrid, ')
          ..write('imageLarge: $imageLarge, ')
          ..write('imageMedium: $imageMedium, ')
          ..write('imageCommon: $imageCommon, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('airDate: $airDate, ')
          ..write('airWeekday: $airWeekday, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('fullJson: $fullJson, ')
          ..write('type: $type, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $DbBangumiCharacterCachesTable extends DbBangumiCharacterCaches
    with TableInfo<$DbBangumiCharacterCachesTable, DbBangumiCharacterCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbBangumiCharacterCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleNameMeta = const VerificationMeta(
    'roleName',
  );
  @override
  late final GeneratedColumn<String> roleName = GeneratedColumn<String>(
    'role_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageSmallMeta = const VerificationMeta(
    'imageSmall',
  );
  @override
  late final GeneratedColumn<String> imageSmall = GeneratedColumn<String>(
    'image_small',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageGridMeta = const VerificationMeta(
    'imageGrid',
  );
  @override
  late final GeneratedColumn<String> imageGrid = GeneratedColumn<String>(
    'image_grid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageLargeMeta = const VerificationMeta(
    'imageLarge',
  );
  @override
  late final GeneratedColumn<String> imageLarge = GeneratedColumn<String>(
    'image_large',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageMediumMeta = const VerificationMeta(
    'imageMedium',
  );
  @override
  late final GeneratedColumn<String> imageMedium = GeneratedColumn<String>(
    'image_medium',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageCommonMeta = const VerificationMeta(
    'imageCommon',
  );
  @override
  late final GeneratedColumn<String> imageCommon = GeneratedColumn<String>(
    'image_common',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localImagePathMeta = const VerificationMeta(
    'localImagePath',
  );
  @override
  late final GeneratedColumn<String> localImagePath = GeneratedColumn<String>(
    'local_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorsJsonMeta = const VerificationMeta(
    'actorsJson',
  );
  @override
  late final GeneratedColumn<String> actorsJson = GeneratedColumn<String>(
    'actors_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    characterId,
    name,
    roleName,
    imageSmall,
    imageGrid,
    imageLarge,
    imageMedium,
    imageCommon,
    localImagePath,
    actorsJson,
    cachedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_bangumi_character_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBangumiCharacterCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('role_name')) {
      context.handle(
        _roleNameMeta,
        roleName.isAcceptableOrUnknown(data['role_name']!, _roleNameMeta),
      );
    } else if (isInserting) {
      context.missing(_roleNameMeta);
    }
    if (data.containsKey('image_small')) {
      context.handle(
        _imageSmallMeta,
        imageSmall.isAcceptableOrUnknown(data['image_small']!, _imageSmallMeta),
      );
    }
    if (data.containsKey('image_grid')) {
      context.handle(
        _imageGridMeta,
        imageGrid.isAcceptableOrUnknown(data['image_grid']!, _imageGridMeta),
      );
    }
    if (data.containsKey('image_large')) {
      context.handle(
        _imageLargeMeta,
        imageLarge.isAcceptableOrUnknown(data['image_large']!, _imageLargeMeta),
      );
    }
    if (data.containsKey('image_medium')) {
      context.handle(
        _imageMediumMeta,
        imageMedium.isAcceptableOrUnknown(
          data['image_medium']!,
          _imageMediumMeta,
        ),
      );
    }
    if (data.containsKey('image_common')) {
      context.handle(
        _imageCommonMeta,
        imageCommon.isAcceptableOrUnknown(
          data['image_common']!,
          _imageCommonMeta,
        ),
      );
    }
    if (data.containsKey('local_image_path')) {
      context.handle(
        _localImagePathMeta,
        localImagePath.isAcceptableOrUnknown(
          data['local_image_path']!,
          _localImagePathMeta,
        ),
      );
    }
    if (data.containsKey('actors_json')) {
      context.handle(
        _actorsJsonMeta,
        actorsJson.isAcceptableOrUnknown(data['actors_json']!, _actorsJsonMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBangumiCharacterCache map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBangumiCharacterCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}character_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      roleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_name'],
      )!,
      imageSmall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_small'],
      ),
      imageGrid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_grid'],
      ),
      imageLarge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_large'],
      ),
      imageMedium: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_medium'],
      ),
      imageCommon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_common'],
      ),
      localImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_image_path'],
      ),
      actorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actors_json'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $DbBangumiCharacterCachesTable createAlias(String alias) {
    return $DbBangumiCharacterCachesTable(attachedDatabase, alias);
  }
}

class DbBangumiCharacterCache extends DataClass
    implements Insertable<DbBangumiCharacterCache> {
  final int id;
  final int subjectId;
  final int characterId;
  final String name;
  final String roleName;
  final String? imageSmall;
  final String? imageGrid;
  final String? imageLarge;
  final String? imageMedium;
  final String? imageCommon;
  final String? localImagePath;
  final String? actorsJson;
  final int cachedAt;
  final int expiresAt;
  const DbBangumiCharacterCache({
    required this.id,
    required this.subjectId,
    required this.characterId,
    required this.name,
    required this.roleName,
    this.imageSmall,
    this.imageGrid,
    this.imageLarge,
    this.imageMedium,
    this.imageCommon,
    this.localImagePath,
    this.actorsJson,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['character_id'] = Variable<int>(characterId);
    map['name'] = Variable<String>(name);
    map['role_name'] = Variable<String>(roleName);
    if (!nullToAbsent || imageSmall != null) {
      map['image_small'] = Variable<String>(imageSmall);
    }
    if (!nullToAbsent || imageGrid != null) {
      map['image_grid'] = Variable<String>(imageGrid);
    }
    if (!nullToAbsent || imageLarge != null) {
      map['image_large'] = Variable<String>(imageLarge);
    }
    if (!nullToAbsent || imageMedium != null) {
      map['image_medium'] = Variable<String>(imageMedium);
    }
    if (!nullToAbsent || imageCommon != null) {
      map['image_common'] = Variable<String>(imageCommon);
    }
    if (!nullToAbsent || localImagePath != null) {
      map['local_image_path'] = Variable<String>(localImagePath);
    }
    if (!nullToAbsent || actorsJson != null) {
      map['actors_json'] = Variable<String>(actorsJson);
    }
    map['cached_at'] = Variable<int>(cachedAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  DbBangumiCharacterCachesCompanion toCompanion(bool nullToAbsent) {
    return DbBangumiCharacterCachesCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      characterId: Value(characterId),
      name: Value(name),
      roleName: Value(roleName),
      imageSmall: imageSmall == null && nullToAbsent
          ? const Value.absent()
          : Value(imageSmall),
      imageGrid: imageGrid == null && nullToAbsent
          ? const Value.absent()
          : Value(imageGrid),
      imageLarge: imageLarge == null && nullToAbsent
          ? const Value.absent()
          : Value(imageLarge),
      imageMedium: imageMedium == null && nullToAbsent
          ? const Value.absent()
          : Value(imageMedium),
      imageCommon: imageCommon == null && nullToAbsent
          ? const Value.absent()
          : Value(imageCommon),
      localImagePath: localImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localImagePath),
      actorsJson: actorsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(actorsJson),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DbBangumiCharacterCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBangumiCharacterCache(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      characterId: serializer.fromJson<int>(json['characterId']),
      name: serializer.fromJson<String>(json['name']),
      roleName: serializer.fromJson<String>(json['roleName']),
      imageSmall: serializer.fromJson<String?>(json['imageSmall']),
      imageGrid: serializer.fromJson<String?>(json['imageGrid']),
      imageLarge: serializer.fromJson<String?>(json['imageLarge']),
      imageMedium: serializer.fromJson<String?>(json['imageMedium']),
      imageCommon: serializer.fromJson<String?>(json['imageCommon']),
      localImagePath: serializer.fromJson<String?>(json['localImagePath']),
      actorsJson: serializer.fromJson<String?>(json['actorsJson']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'characterId': serializer.toJson<int>(characterId),
      'name': serializer.toJson<String>(name),
      'roleName': serializer.toJson<String>(roleName),
      'imageSmall': serializer.toJson<String?>(imageSmall),
      'imageGrid': serializer.toJson<String?>(imageGrid),
      'imageLarge': serializer.toJson<String?>(imageLarge),
      'imageMedium': serializer.toJson<String?>(imageMedium),
      'imageCommon': serializer.toJson<String?>(imageCommon),
      'localImagePath': serializer.toJson<String?>(localImagePath),
      'actorsJson': serializer.toJson<String?>(actorsJson),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  DbBangumiCharacterCache copyWith({
    int? id,
    int? subjectId,
    int? characterId,
    String? name,
    String? roleName,
    Value<String?> imageSmall = const Value.absent(),
    Value<String?> imageGrid = const Value.absent(),
    Value<String?> imageLarge = const Value.absent(),
    Value<String?> imageMedium = const Value.absent(),
    Value<String?> imageCommon = const Value.absent(),
    Value<String?> localImagePath = const Value.absent(),
    Value<String?> actorsJson = const Value.absent(),
    int? cachedAt,
    int? expiresAt,
  }) => DbBangumiCharacterCache(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    characterId: characterId ?? this.characterId,
    name: name ?? this.name,
    roleName: roleName ?? this.roleName,
    imageSmall: imageSmall.present ? imageSmall.value : this.imageSmall,
    imageGrid: imageGrid.present ? imageGrid.value : this.imageGrid,
    imageLarge: imageLarge.present ? imageLarge.value : this.imageLarge,
    imageMedium: imageMedium.present ? imageMedium.value : this.imageMedium,
    imageCommon: imageCommon.present ? imageCommon.value : this.imageCommon,
    localImagePath: localImagePath.present
        ? localImagePath.value
        : this.localImagePath,
    actorsJson: actorsJson.present ? actorsJson.value : this.actorsJson,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  DbBangumiCharacterCache copyWithCompanion(
    DbBangumiCharacterCachesCompanion data,
  ) {
    return DbBangumiCharacterCache(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      name: data.name.present ? data.name.value : this.name,
      roleName: data.roleName.present ? data.roleName.value : this.roleName,
      imageSmall: data.imageSmall.present
          ? data.imageSmall.value
          : this.imageSmall,
      imageGrid: data.imageGrid.present ? data.imageGrid.value : this.imageGrid,
      imageLarge: data.imageLarge.present
          ? data.imageLarge.value
          : this.imageLarge,
      imageMedium: data.imageMedium.present
          ? data.imageMedium.value
          : this.imageMedium,
      imageCommon: data.imageCommon.present
          ? data.imageCommon.value
          : this.imageCommon,
      localImagePath: data.localImagePath.present
          ? data.localImagePath.value
          : this.localImagePath,
      actorsJson: data.actorsJson.present
          ? data.actorsJson.value
          : this.actorsJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiCharacterCache(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('characterId: $characterId, ')
          ..write('name: $name, ')
          ..write('roleName: $roleName, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageGrid: $imageGrid, ')
          ..write('imageLarge: $imageLarge, ')
          ..write('imageMedium: $imageMedium, ')
          ..write('imageCommon: $imageCommon, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('actorsJson: $actorsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    characterId,
    name,
    roleName,
    imageSmall,
    imageGrid,
    imageLarge,
    imageMedium,
    imageCommon,
    localImagePath,
    actorsJson,
    cachedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBangumiCharacterCache &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.characterId == this.characterId &&
          other.name == this.name &&
          other.roleName == this.roleName &&
          other.imageSmall == this.imageSmall &&
          other.imageGrid == this.imageGrid &&
          other.imageLarge == this.imageLarge &&
          other.imageMedium == this.imageMedium &&
          other.imageCommon == this.imageCommon &&
          other.localImagePath == this.localImagePath &&
          other.actorsJson == this.actorsJson &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class DbBangumiCharacterCachesCompanion
    extends UpdateCompanion<DbBangumiCharacterCache> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<int> characterId;
  final Value<String> name;
  final Value<String> roleName;
  final Value<String?> imageSmall;
  final Value<String?> imageGrid;
  final Value<String?> imageLarge;
  final Value<String?> imageMedium;
  final Value<String?> imageCommon;
  final Value<String?> localImagePath;
  final Value<String?> actorsJson;
  final Value<int> cachedAt;
  final Value<int> expiresAt;
  const DbBangumiCharacterCachesCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.name = const Value.absent(),
    this.roleName = const Value.absent(),
    this.imageSmall = const Value.absent(),
    this.imageGrid = const Value.absent(),
    this.imageLarge = const Value.absent(),
    this.imageMedium = const Value.absent(),
    this.imageCommon = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.actorsJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  DbBangumiCharacterCachesCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required int characterId,
    required String name,
    required String roleName,
    this.imageSmall = const Value.absent(),
    this.imageGrid = const Value.absent(),
    this.imageLarge = const Value.absent(),
    this.imageMedium = const Value.absent(),
    this.imageCommon = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.actorsJson = const Value.absent(),
    required int cachedAt,
    required int expiresAt,
  }) : subjectId = Value(subjectId),
       characterId = Value(characterId),
       name = Value(name),
       roleName = Value(roleName),
       cachedAt = Value(cachedAt),
       expiresAt = Value(expiresAt);
  static Insertable<DbBangumiCharacterCache> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<int>? characterId,
    Expression<String>? name,
    Expression<String>? roleName,
    Expression<String>? imageSmall,
    Expression<String>? imageGrid,
    Expression<String>? imageLarge,
    Expression<String>? imageMedium,
    Expression<String>? imageCommon,
    Expression<String>? localImagePath,
    Expression<String>? actorsJson,
    Expression<int>? cachedAt,
    Expression<int>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (characterId != null) 'character_id': characterId,
      if (name != null) 'name': name,
      if (roleName != null) 'role_name': roleName,
      if (imageSmall != null) 'image_small': imageSmall,
      if (imageGrid != null) 'image_grid': imageGrid,
      if (imageLarge != null) 'image_large': imageLarge,
      if (imageMedium != null) 'image_medium': imageMedium,
      if (imageCommon != null) 'image_common': imageCommon,
      if (localImagePath != null) 'local_image_path': localImagePath,
      if (actorsJson != null) 'actors_json': actorsJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  DbBangumiCharacterCachesCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<int>? characterId,
    Value<String>? name,
    Value<String>? roleName,
    Value<String?>? imageSmall,
    Value<String?>? imageGrid,
    Value<String?>? imageLarge,
    Value<String?>? imageMedium,
    Value<String?>? imageCommon,
    Value<String?>? localImagePath,
    Value<String?>? actorsJson,
    Value<int>? cachedAt,
    Value<int>? expiresAt,
  }) {
    return DbBangumiCharacterCachesCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      characterId: characterId ?? this.characterId,
      name: name ?? this.name,
      roleName: roleName ?? this.roleName,
      imageSmall: imageSmall ?? this.imageSmall,
      imageGrid: imageGrid ?? this.imageGrid,
      imageLarge: imageLarge ?? this.imageLarge,
      imageMedium: imageMedium ?? this.imageMedium,
      imageCommon: imageCommon ?? this.imageCommon,
      localImagePath: localImagePath ?? this.localImagePath,
      actorsJson: actorsJson ?? this.actorsJson,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (roleName.present) {
      map['role_name'] = Variable<String>(roleName.value);
    }
    if (imageSmall.present) {
      map['image_small'] = Variable<String>(imageSmall.value);
    }
    if (imageGrid.present) {
      map['image_grid'] = Variable<String>(imageGrid.value);
    }
    if (imageLarge.present) {
      map['image_large'] = Variable<String>(imageLarge.value);
    }
    if (imageMedium.present) {
      map['image_medium'] = Variable<String>(imageMedium.value);
    }
    if (imageCommon.present) {
      map['image_common'] = Variable<String>(imageCommon.value);
    }
    if (localImagePath.present) {
      map['local_image_path'] = Variable<String>(localImagePath.value);
    }
    if (actorsJson.present) {
      map['actors_json'] = Variable<String>(actorsJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiCharacterCachesCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('characterId: $characterId, ')
          ..write('name: $name, ')
          ..write('roleName: $roleName, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageGrid: $imageGrid, ')
          ..write('imageLarge: $imageLarge, ')
          ..write('imageMedium: $imageMedium, ')
          ..write('imageCommon: $imageCommon, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('actorsJson: $actorsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $DbBangumiRelationCachesTable extends DbBangumiRelationCaches
    with TableInfo<$DbBangumiRelationCachesTable, DbBangumiRelationCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbBangumiRelationCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceSubjectIdMeta = const VerificationMeta(
    'sourceSubjectId',
  );
  @override
  late final GeneratedColumn<int> sourceSubjectId = GeneratedColumn<int>(
    'source_subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relatedSubjectIdMeta = const VerificationMeta(
    'relatedSubjectId',
  );
  @override
  late final GeneratedColumn<int> relatedSubjectId = GeneratedColumn<int>(
    'related_subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameCnMeta = const VerificationMeta('nameCn');
  @override
  late final GeneratedColumn<String> nameCn = GeneratedColumn<String>(
    'name_cn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relationMeta = const VerificationMeta(
    'relation',
  );
  @override
  late final GeneratedColumn<String> relation = GeneratedColumn<String>(
    'relation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localImagePathMeta = const VerificationMeta(
    'localImagePath',
  );
  @override
  late final GeneratedColumn<String> localImagePath = GeneratedColumn<String>(
    'local_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceSubjectId,
    relatedSubjectId,
    name,
    nameCn,
    relation,
    imageUrl,
    localImagePath,
    cachedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_bangumi_relation_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBangumiRelationCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_subject_id')) {
      context.handle(
        _sourceSubjectIdMeta,
        sourceSubjectId.isAcceptableOrUnknown(
          data['source_subject_id']!,
          _sourceSubjectIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceSubjectIdMeta);
    }
    if (data.containsKey('related_subject_id')) {
      context.handle(
        _relatedSubjectIdMeta,
        relatedSubjectId.isAcceptableOrUnknown(
          data['related_subject_id']!,
          _relatedSubjectIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relatedSubjectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_cn')) {
      context.handle(
        _nameCnMeta,
        nameCn.isAcceptableOrUnknown(data['name_cn']!, _nameCnMeta),
      );
    }
    if (data.containsKey('relation')) {
      context.handle(
        _relationMeta,
        relation.isAcceptableOrUnknown(data['relation']!, _relationMeta),
      );
    } else if (isInserting) {
      context.missing(_relationMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('local_image_path')) {
      context.handle(
        _localImagePathMeta,
        localImagePath.isAcceptableOrUnknown(
          data['local_image_path']!,
          _localImagePathMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBangumiRelationCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBangumiRelationCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceSubjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_subject_id'],
      )!,
      relatedSubjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}related_subject_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameCn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_cn'],
      ),
      relation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      localImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_image_path'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $DbBangumiRelationCachesTable createAlias(String alias) {
    return $DbBangumiRelationCachesTable(attachedDatabase, alias);
  }
}

class DbBangumiRelationCache extends DataClass
    implements Insertable<DbBangumiRelationCache> {
  final int id;
  final int sourceSubjectId;
  final int relatedSubjectId;
  final String name;
  final String? nameCn;
  final String relation;
  final String? imageUrl;
  final String? localImagePath;
  final int cachedAt;
  final int expiresAt;
  const DbBangumiRelationCache({
    required this.id,
    required this.sourceSubjectId,
    required this.relatedSubjectId,
    required this.name,
    this.nameCn,
    required this.relation,
    this.imageUrl,
    this.localImagePath,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_subject_id'] = Variable<int>(sourceSubjectId);
    map['related_subject_id'] = Variable<int>(relatedSubjectId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nameCn != null) {
      map['name_cn'] = Variable<String>(nameCn);
    }
    map['relation'] = Variable<String>(relation);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || localImagePath != null) {
      map['local_image_path'] = Variable<String>(localImagePath);
    }
    map['cached_at'] = Variable<int>(cachedAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  DbBangumiRelationCachesCompanion toCompanion(bool nullToAbsent) {
    return DbBangumiRelationCachesCompanion(
      id: Value(id),
      sourceSubjectId: Value(sourceSubjectId),
      relatedSubjectId: Value(relatedSubjectId),
      name: Value(name),
      nameCn: nameCn == null && nullToAbsent
          ? const Value.absent()
          : Value(nameCn),
      relation: Value(relation),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      localImagePath: localImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localImagePath),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DbBangumiRelationCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBangumiRelationCache(
      id: serializer.fromJson<int>(json['id']),
      sourceSubjectId: serializer.fromJson<int>(json['sourceSubjectId']),
      relatedSubjectId: serializer.fromJson<int>(json['relatedSubjectId']),
      name: serializer.fromJson<String>(json['name']),
      nameCn: serializer.fromJson<String?>(json['nameCn']),
      relation: serializer.fromJson<String>(json['relation']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      localImagePath: serializer.fromJson<String?>(json['localImagePath']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceSubjectId': serializer.toJson<int>(sourceSubjectId),
      'relatedSubjectId': serializer.toJson<int>(relatedSubjectId),
      'name': serializer.toJson<String>(name),
      'nameCn': serializer.toJson<String?>(nameCn),
      'relation': serializer.toJson<String>(relation),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'localImagePath': serializer.toJson<String?>(localImagePath),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  DbBangumiRelationCache copyWith({
    int? id,
    int? sourceSubjectId,
    int? relatedSubjectId,
    String? name,
    Value<String?> nameCn = const Value.absent(),
    String? relation,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> localImagePath = const Value.absent(),
    int? cachedAt,
    int? expiresAt,
  }) => DbBangumiRelationCache(
    id: id ?? this.id,
    sourceSubjectId: sourceSubjectId ?? this.sourceSubjectId,
    relatedSubjectId: relatedSubjectId ?? this.relatedSubjectId,
    name: name ?? this.name,
    nameCn: nameCn.present ? nameCn.value : this.nameCn,
    relation: relation ?? this.relation,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    localImagePath: localImagePath.present
        ? localImagePath.value
        : this.localImagePath,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  DbBangumiRelationCache copyWithCompanion(
    DbBangumiRelationCachesCompanion data,
  ) {
    return DbBangumiRelationCache(
      id: data.id.present ? data.id.value : this.id,
      sourceSubjectId: data.sourceSubjectId.present
          ? data.sourceSubjectId.value
          : this.sourceSubjectId,
      relatedSubjectId: data.relatedSubjectId.present
          ? data.relatedSubjectId.value
          : this.relatedSubjectId,
      name: data.name.present ? data.name.value : this.name,
      nameCn: data.nameCn.present ? data.nameCn.value : this.nameCn,
      relation: data.relation.present ? data.relation.value : this.relation,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      localImagePath: data.localImagePath.present
          ? data.localImagePath.value
          : this.localImagePath,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiRelationCache(')
          ..write('id: $id, ')
          ..write('sourceSubjectId: $sourceSubjectId, ')
          ..write('relatedSubjectId: $relatedSubjectId, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('relation: $relation, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceSubjectId,
    relatedSubjectId,
    name,
    nameCn,
    relation,
    imageUrl,
    localImagePath,
    cachedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBangumiRelationCache &&
          other.id == this.id &&
          other.sourceSubjectId == this.sourceSubjectId &&
          other.relatedSubjectId == this.relatedSubjectId &&
          other.name == this.name &&
          other.nameCn == this.nameCn &&
          other.relation == this.relation &&
          other.imageUrl == this.imageUrl &&
          other.localImagePath == this.localImagePath &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class DbBangumiRelationCachesCompanion
    extends UpdateCompanion<DbBangumiRelationCache> {
  final Value<int> id;
  final Value<int> sourceSubjectId;
  final Value<int> relatedSubjectId;
  final Value<String> name;
  final Value<String?> nameCn;
  final Value<String> relation;
  final Value<String?> imageUrl;
  final Value<String?> localImagePath;
  final Value<int> cachedAt;
  final Value<int> expiresAt;
  const DbBangumiRelationCachesCompanion({
    this.id = const Value.absent(),
    this.sourceSubjectId = const Value.absent(),
    this.relatedSubjectId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameCn = const Value.absent(),
    this.relation = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  DbBangumiRelationCachesCompanion.insert({
    this.id = const Value.absent(),
    required int sourceSubjectId,
    required int relatedSubjectId,
    required String name,
    this.nameCn = const Value.absent(),
    required String relation,
    this.imageUrl = const Value.absent(),
    this.localImagePath = const Value.absent(),
    required int cachedAt,
    required int expiresAt,
  }) : sourceSubjectId = Value(sourceSubjectId),
       relatedSubjectId = Value(relatedSubjectId),
       name = Value(name),
       relation = Value(relation),
       cachedAt = Value(cachedAt),
       expiresAt = Value(expiresAt);
  static Insertable<DbBangumiRelationCache> custom({
    Expression<int>? id,
    Expression<int>? sourceSubjectId,
    Expression<int>? relatedSubjectId,
    Expression<String>? name,
    Expression<String>? nameCn,
    Expression<String>? relation,
    Expression<String>? imageUrl,
    Expression<String>? localImagePath,
    Expression<int>? cachedAt,
    Expression<int>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceSubjectId != null) 'source_subject_id': sourceSubjectId,
      if (relatedSubjectId != null) 'related_subject_id': relatedSubjectId,
      if (name != null) 'name': name,
      if (nameCn != null) 'name_cn': nameCn,
      if (relation != null) 'relation': relation,
      if (imageUrl != null) 'image_url': imageUrl,
      if (localImagePath != null) 'local_image_path': localImagePath,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  DbBangumiRelationCachesCompanion copyWith({
    Value<int>? id,
    Value<int>? sourceSubjectId,
    Value<int>? relatedSubjectId,
    Value<String>? name,
    Value<String?>? nameCn,
    Value<String>? relation,
    Value<String?>? imageUrl,
    Value<String?>? localImagePath,
    Value<int>? cachedAt,
    Value<int>? expiresAt,
  }) {
    return DbBangumiRelationCachesCompanion(
      id: id ?? this.id,
      sourceSubjectId: sourceSubjectId ?? this.sourceSubjectId,
      relatedSubjectId: relatedSubjectId ?? this.relatedSubjectId,
      name: name ?? this.name,
      nameCn: nameCn ?? this.nameCn,
      relation: relation ?? this.relation,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceSubjectId.present) {
      map['source_subject_id'] = Variable<int>(sourceSubjectId.value);
    }
    if (relatedSubjectId.present) {
      map['related_subject_id'] = Variable<int>(relatedSubjectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameCn.present) {
      map['name_cn'] = Variable<String>(nameCn.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(relation.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (localImagePath.present) {
      map['local_image_path'] = Variable<String>(localImagePath.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiRelationCachesCompanion(')
          ..write('id: $id, ')
          ..write('sourceSubjectId: $sourceSubjectId, ')
          ..write('relatedSubjectId: $relatedSubjectId, ')
          ..write('name: $name, ')
          ..write('nameCn: $nameCn, ')
          ..write('relation: $relation, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $DbTimetableCachesTable extends DbTimetableCaches
    with TableInfo<$DbTimetableCachesTable, DbTimetableCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbTimetableCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _quarterMeta = const VerificationMeta(
    'quarter',
  );
  @override
  late final GeneratedColumn<String> quarter = GeneratedColumn<String>(
    'quarter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _animesJsonMeta = const VerificationMeta(
    'animesJson',
  );
  @override
  late final GeneratedColumn<String> animesJson = GeneratedColumn<String>(
    'animes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    quarter,
    animesJson,
    cachedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_timetable_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbTimetableCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('quarter')) {
      context.handle(
        _quarterMeta,
        quarter.isAcceptableOrUnknown(data['quarter']!, _quarterMeta),
      );
    } else if (isInserting) {
      context.missing(_quarterMeta);
    }
    if (data.containsKey('animes_json')) {
      context.handle(
        _animesJsonMeta,
        animesJson.isAcceptableOrUnknown(data['animes_json']!, _animesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_animesJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbTimetableCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbTimetableCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      quarter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quarter'],
      )!,
      animesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}animes_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $DbTimetableCachesTable createAlias(String alias) {
    return $DbTimetableCachesTable(attachedDatabase, alias);
  }
}

class DbTimetableCache extends DataClass
    implements Insertable<DbTimetableCache> {
  final int id;
  final String quarter;
  final String animesJson;
  final int cachedAt;
  final int expiresAt;
  const DbTimetableCache({
    required this.id,
    required this.quarter,
    required this.animesJson,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['quarter'] = Variable<String>(quarter);
    map['animes_json'] = Variable<String>(animesJson);
    map['cached_at'] = Variable<int>(cachedAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  DbTimetableCachesCompanion toCompanion(bool nullToAbsent) {
    return DbTimetableCachesCompanion(
      id: Value(id),
      quarter: Value(quarter),
      animesJson: Value(animesJson),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DbTimetableCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbTimetableCache(
      id: serializer.fromJson<int>(json['id']),
      quarter: serializer.fromJson<String>(json['quarter']),
      animesJson: serializer.fromJson<String>(json['animesJson']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'quarter': serializer.toJson<String>(quarter),
      'animesJson': serializer.toJson<String>(animesJson),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  DbTimetableCache copyWith({
    int? id,
    String? quarter,
    String? animesJson,
    int? cachedAt,
    int? expiresAt,
  }) => DbTimetableCache(
    id: id ?? this.id,
    quarter: quarter ?? this.quarter,
    animesJson: animesJson ?? this.animesJson,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  DbTimetableCache copyWithCompanion(DbTimetableCachesCompanion data) {
    return DbTimetableCache(
      id: data.id.present ? data.id.value : this.id,
      quarter: data.quarter.present ? data.quarter.value : this.quarter,
      animesJson: data.animesJson.present
          ? data.animesJson.value
          : this.animesJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbTimetableCache(')
          ..write('id: $id, ')
          ..write('quarter: $quarter, ')
          ..write('animesJson: $animesJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, quarter, animesJson, cachedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbTimetableCache &&
          other.id == this.id &&
          other.quarter == this.quarter &&
          other.animesJson == this.animesJson &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class DbTimetableCachesCompanion extends UpdateCompanion<DbTimetableCache> {
  final Value<int> id;
  final Value<String> quarter;
  final Value<String> animesJson;
  final Value<int> cachedAt;
  final Value<int> expiresAt;
  const DbTimetableCachesCompanion({
    this.id = const Value.absent(),
    this.quarter = const Value.absent(),
    this.animesJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  DbTimetableCachesCompanion.insert({
    this.id = const Value.absent(),
    required String quarter,
    required String animesJson,
    required int cachedAt,
    required int expiresAt,
  }) : quarter = Value(quarter),
       animesJson = Value(animesJson),
       cachedAt = Value(cachedAt),
       expiresAt = Value(expiresAt);
  static Insertable<DbTimetableCache> custom({
    Expression<int>? id,
    Expression<String>? quarter,
    Expression<String>? animesJson,
    Expression<int>? cachedAt,
    Expression<int>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (quarter != null) 'quarter': quarter,
      if (animesJson != null) 'animes_json': animesJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  DbTimetableCachesCompanion copyWith({
    Value<int>? id,
    Value<String>? quarter,
    Value<String>? animesJson,
    Value<int>? cachedAt,
    Value<int>? expiresAt,
  }) {
    return DbTimetableCachesCompanion(
      id: id ?? this.id,
      quarter: quarter ?? this.quarter,
      animesJson: animesJson ?? this.animesJson,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (quarter.present) {
      map['quarter'] = Variable<String>(quarter.value);
    }
    if (animesJson.present) {
      map['animes_json'] = Variable<String>(animesJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbTimetableCachesCompanion(')
          ..write('id: $id, ')
          ..write('quarter: $quarter, ')
          ..write('animesJson: $animesJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $DbRankingCachesTable extends DbRankingCaches
    with TableInfo<$DbRankingCachesTable, DbRankingCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbRankingCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sortTypeMeta = const VerificationMeta(
    'sortType',
  );
  @override
  late final GeneratedColumn<String> sortType = GeneratedColumn<String>(
    'sort_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultsJsonMeta = const VerificationMeta(
    'resultsJson',
  );
  @override
  late final GeneratedColumn<String> resultsJson = GeneratedColumn<String>(
    'results_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cacheKey,
    sortType,
    year,
    tagsJson,
    page,
    resultsJson,
    cachedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_ranking_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbRankingCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('sort_type')) {
      context.handle(
        _sortTypeMeta,
        sortType.isAcceptableOrUnknown(data['sort_type']!, _sortTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sortTypeMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('results_json')) {
      context.handle(
        _resultsJsonMeta,
        resultsJson.isAcceptableOrUnknown(
          data['results_json']!,
          _resultsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultsJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbRankingCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbRankingCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      sortType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_type'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}year'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      ),
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      resultsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}results_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $DbRankingCachesTable createAlias(String alias) {
    return $DbRankingCachesTable(attachedDatabase, alias);
  }
}

class DbRankingCache extends DataClass implements Insertable<DbRankingCache> {
  final int id;
  final String cacheKey;
  final String sortType;
  final String? year;
  final String? tagsJson;
  final int page;
  final String resultsJson;
  final int cachedAt;
  final int expiresAt;
  const DbRankingCache({
    required this.id,
    required this.cacheKey,
    required this.sortType,
    this.year,
    this.tagsJson,
    required this.page,
    required this.resultsJson,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cache_key'] = Variable<String>(cacheKey);
    map['sort_type'] = Variable<String>(sortType);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<String>(year);
    }
    if (!nullToAbsent || tagsJson != null) {
      map['tags_json'] = Variable<String>(tagsJson);
    }
    map['page'] = Variable<int>(page);
    map['results_json'] = Variable<String>(resultsJson);
    map['cached_at'] = Variable<int>(cachedAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  DbRankingCachesCompanion toCompanion(bool nullToAbsent) {
    return DbRankingCachesCompanion(
      id: Value(id),
      cacheKey: Value(cacheKey),
      sortType: Value(sortType),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      tagsJson: tagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsJson),
      page: Value(page),
      resultsJson: Value(resultsJson),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DbRankingCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbRankingCache(
      id: serializer.fromJson<int>(json['id']),
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      sortType: serializer.fromJson<String>(json['sortType']),
      year: serializer.fromJson<String?>(json['year']),
      tagsJson: serializer.fromJson<String?>(json['tagsJson']),
      page: serializer.fromJson<int>(json['page']),
      resultsJson: serializer.fromJson<String>(json['resultsJson']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cacheKey': serializer.toJson<String>(cacheKey),
      'sortType': serializer.toJson<String>(sortType),
      'year': serializer.toJson<String?>(year),
      'tagsJson': serializer.toJson<String?>(tagsJson),
      'page': serializer.toJson<int>(page),
      'resultsJson': serializer.toJson<String>(resultsJson),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  DbRankingCache copyWith({
    int? id,
    String? cacheKey,
    String? sortType,
    Value<String?> year = const Value.absent(),
    Value<String?> tagsJson = const Value.absent(),
    int? page,
    String? resultsJson,
    int? cachedAt,
    int? expiresAt,
  }) => DbRankingCache(
    id: id ?? this.id,
    cacheKey: cacheKey ?? this.cacheKey,
    sortType: sortType ?? this.sortType,
    year: year.present ? year.value : this.year,
    tagsJson: tagsJson.present ? tagsJson.value : this.tagsJson,
    page: page ?? this.page,
    resultsJson: resultsJson ?? this.resultsJson,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  DbRankingCache copyWithCompanion(DbRankingCachesCompanion data) {
    return DbRankingCache(
      id: data.id.present ? data.id.value : this.id,
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      sortType: data.sortType.present ? data.sortType.value : this.sortType,
      year: data.year.present ? data.year.value : this.year,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      page: data.page.present ? data.page.value : this.page,
      resultsJson: data.resultsJson.present
          ? data.resultsJson.value
          : this.resultsJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbRankingCache(')
          ..write('id: $id, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('sortType: $sortType, ')
          ..write('year: $year, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('page: $page, ')
          ..write('resultsJson: $resultsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cacheKey,
    sortType,
    year,
    tagsJson,
    page,
    resultsJson,
    cachedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbRankingCache &&
          other.id == this.id &&
          other.cacheKey == this.cacheKey &&
          other.sortType == this.sortType &&
          other.year == this.year &&
          other.tagsJson == this.tagsJson &&
          other.page == this.page &&
          other.resultsJson == this.resultsJson &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class DbRankingCachesCompanion extends UpdateCompanion<DbRankingCache> {
  final Value<int> id;
  final Value<String> cacheKey;
  final Value<String> sortType;
  final Value<String?> year;
  final Value<String?> tagsJson;
  final Value<int> page;
  final Value<String> resultsJson;
  final Value<int> cachedAt;
  final Value<int> expiresAt;
  const DbRankingCachesCompanion({
    this.id = const Value.absent(),
    this.cacheKey = const Value.absent(),
    this.sortType = const Value.absent(),
    this.year = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.page = const Value.absent(),
    this.resultsJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  DbRankingCachesCompanion.insert({
    this.id = const Value.absent(),
    required String cacheKey,
    required String sortType,
    this.year = const Value.absent(),
    this.tagsJson = const Value.absent(),
    required int page,
    required String resultsJson,
    required int cachedAt,
    required int expiresAt,
  }) : cacheKey = Value(cacheKey),
       sortType = Value(sortType),
       page = Value(page),
       resultsJson = Value(resultsJson),
       cachedAt = Value(cachedAt),
       expiresAt = Value(expiresAt);
  static Insertable<DbRankingCache> custom({
    Expression<int>? id,
    Expression<String>? cacheKey,
    Expression<String>? sortType,
    Expression<String>? year,
    Expression<String>? tagsJson,
    Expression<int>? page,
    Expression<String>? resultsJson,
    Expression<int>? cachedAt,
    Expression<int>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cacheKey != null) 'cache_key': cacheKey,
      if (sortType != null) 'sort_type': sortType,
      if (year != null) 'year': year,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (page != null) 'page': page,
      if (resultsJson != null) 'results_json': resultsJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  DbRankingCachesCompanion copyWith({
    Value<int>? id,
    Value<String>? cacheKey,
    Value<String>? sortType,
    Value<String?>? year,
    Value<String?>? tagsJson,
    Value<int>? page,
    Value<String>? resultsJson,
    Value<int>? cachedAt,
    Value<int>? expiresAt,
  }) {
    return DbRankingCachesCompanion(
      id: id ?? this.id,
      cacheKey: cacheKey ?? this.cacheKey,
      sortType: sortType ?? this.sortType,
      year: year ?? this.year,
      tagsJson: tagsJson ?? this.tagsJson,
      page: page ?? this.page,
      resultsJson: resultsJson ?? this.resultsJson,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (sortType.present) {
      map['sort_type'] = Variable<String>(sortType.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (resultsJson.present) {
      map['results_json'] = Variable<String>(resultsJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbRankingCachesCompanion(')
          ..write('id: $id, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('sortType: $sortType, ')
          ..write('year: $year, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('page: $page, ')
          ..write('resultsJson: $resultsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $DbBangumiEpisodeCachesTable extends DbBangumiEpisodeCaches
    with TableInfo<$DbBangumiEpisodeCachesTable, DbBangumiEpisodeCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbBangumiEpisodeCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _episodesJsonMeta = const VerificationMeta(
    'episodesJson',
  );
  @override
  late final GeneratedColumn<String> episodesJson = GeneratedColumn<String>(
    'episodes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    episodesJson,
    cachedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_bangumi_episode_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBangumiEpisodeCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('episodes_json')) {
      context.handle(
        _episodesJsonMeta,
        episodesJson.isAcceptableOrUnknown(
          data['episodes_json']!,
          _episodesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodesJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBangumiEpisodeCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBangumiEpisodeCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      episodesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episodes_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $DbBangumiEpisodeCachesTable createAlias(String alias) {
    return $DbBangumiEpisodeCachesTable(attachedDatabase, alias);
  }
}

class DbBangumiEpisodeCache extends DataClass
    implements Insertable<DbBangumiEpisodeCache> {
  final int id;
  final int subjectId;
  final String episodesJson;
  final int cachedAt;
  final int expiresAt;
  const DbBangumiEpisodeCache({
    required this.id,
    required this.subjectId,
    required this.episodesJson,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['episodes_json'] = Variable<String>(episodesJson);
    map['cached_at'] = Variable<int>(cachedAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  DbBangumiEpisodeCachesCompanion toCompanion(bool nullToAbsent) {
    return DbBangumiEpisodeCachesCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      episodesJson: Value(episodesJson),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DbBangumiEpisodeCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBangumiEpisodeCache(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      episodesJson: serializer.fromJson<String>(json['episodesJson']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'episodesJson': serializer.toJson<String>(episodesJson),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  DbBangumiEpisodeCache copyWith({
    int? id,
    int? subjectId,
    String? episodesJson,
    int? cachedAt,
    int? expiresAt,
  }) => DbBangumiEpisodeCache(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    episodesJson: episodesJson ?? this.episodesJson,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  DbBangumiEpisodeCache copyWithCompanion(
    DbBangumiEpisodeCachesCompanion data,
  ) {
    return DbBangumiEpisodeCache(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      episodesJson: data.episodesJson.present
          ? data.episodesJson.value
          : this.episodesJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiEpisodeCache(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodesJson: $episodesJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, episodesJson, cachedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBangumiEpisodeCache &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.episodesJson == this.episodesJson &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class DbBangumiEpisodeCachesCompanion
    extends UpdateCompanion<DbBangumiEpisodeCache> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> episodesJson;
  final Value<int> cachedAt;
  final Value<int> expiresAt;
  const DbBangumiEpisodeCachesCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.episodesJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  DbBangumiEpisodeCachesCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String episodesJson,
    required int cachedAt,
    required int expiresAt,
  }) : subjectId = Value(subjectId),
       episodesJson = Value(episodesJson),
       cachedAt = Value(cachedAt),
       expiresAt = Value(expiresAt);
  static Insertable<DbBangumiEpisodeCache> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? episodesJson,
    Expression<int>? cachedAt,
    Expression<int>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (episodesJson != null) 'episodes_json': episodesJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  DbBangumiEpisodeCachesCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? episodesJson,
    Value<int>? cachedAt,
    Value<int>? expiresAt,
  }) {
    return DbBangumiEpisodeCachesCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      episodesJson: episodesJson ?? this.episodesJson,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (episodesJson.present) {
      map['episodes_json'] = Variable<String>(episodesJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiEpisodeCachesCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodesJson: $episodesJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $DbBangumiPersonCachesTable extends DbBangumiPersonCaches
    with TableInfo<$DbBangumiPersonCachesTable, DbBangumiPersonCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbBangumiPersonCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _personsJsonMeta = const VerificationMeta(
    'personsJson',
  );
  @override
  late final GeneratedColumn<String> personsJson = GeneratedColumn<String>(
    'persons_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    personsJson,
    cachedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_bangumi_person_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbBangumiPersonCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('persons_json')) {
      context.handle(
        _personsJsonMeta,
        personsJson.isAcceptableOrUnknown(
          data['persons_json']!,
          _personsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_personsJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbBangumiPersonCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbBangumiPersonCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      personsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persons_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $DbBangumiPersonCachesTable createAlias(String alias) {
    return $DbBangumiPersonCachesTable(attachedDatabase, alias);
  }
}

class DbBangumiPersonCache extends DataClass
    implements Insertable<DbBangumiPersonCache> {
  final int id;
  final int subjectId;
  final String personsJson;
  final int cachedAt;
  final int expiresAt;
  const DbBangumiPersonCache({
    required this.id,
    required this.subjectId,
    required this.personsJson,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['persons_json'] = Variable<String>(personsJson);
    map['cached_at'] = Variable<int>(cachedAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  DbBangumiPersonCachesCompanion toCompanion(bool nullToAbsent) {
    return DbBangumiPersonCachesCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      personsJson: Value(personsJson),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory DbBangumiPersonCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbBangumiPersonCache(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      personsJson: serializer.fromJson<String>(json['personsJson']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'personsJson': serializer.toJson<String>(personsJson),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  DbBangumiPersonCache copyWith({
    int? id,
    int? subjectId,
    String? personsJson,
    int? cachedAt,
    int? expiresAt,
  }) => DbBangumiPersonCache(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    personsJson: personsJson ?? this.personsJson,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  DbBangumiPersonCache copyWithCompanion(DbBangumiPersonCachesCompanion data) {
    return DbBangumiPersonCache(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      personsJson: data.personsJson.present
          ? data.personsJson.value
          : this.personsJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiPersonCache(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('personsJson: $personsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, personsJson, cachedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbBangumiPersonCache &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.personsJson == this.personsJson &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class DbBangumiPersonCachesCompanion
    extends UpdateCompanion<DbBangumiPersonCache> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> personsJson;
  final Value<int> cachedAt;
  final Value<int> expiresAt;
  const DbBangumiPersonCachesCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.personsJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  DbBangumiPersonCachesCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String personsJson,
    required int cachedAt,
    required int expiresAt,
  }) : subjectId = Value(subjectId),
       personsJson = Value(personsJson),
       cachedAt = Value(cachedAt),
       expiresAt = Value(expiresAt);
  static Insertable<DbBangumiPersonCache> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? personsJson,
    Expression<int>? cachedAt,
    Expression<int>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (personsJson != null) 'persons_json': personsJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  DbBangumiPersonCachesCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? personsJson,
    Value<int>? cachedAt,
    Value<int>? expiresAt,
  }) {
    return DbBangumiPersonCachesCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      personsJson: personsJson ?? this.personsJson,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (personsJson.present) {
      map['persons_json'] = Variable<String>(personsJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbBangumiPersonCachesCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('personsJson: $personsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $DbDownloadRecordsTable extends DbDownloadRecords
    with TableInfo<$DbDownloadRecordsTable, DbDownloadRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbDownloadRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _infoHashMeta = const VerificationMeta(
    'infoHash',
  );
  @override
  late final GeneratedColumn<String> infoHash = GeneratedColumn<String>(
    'info_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _magnetMeta = const VerificationMeta('magnet');
  @override
  late final GeneratedColumn<String> magnet = GeneratedColumn<String>(
    'magnet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _animeNameMeta = const VerificationMeta(
    'animeName',
  );
  @override
  late final GeneratedColumn<String> animeName = GeneratedColumn<String>(
    'anime_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bangumiIdMeta = const VerificationMeta(
    'bangumiId',
  );
  @override
  late final GeneratedColumn<String> bangumiId = GeneratedColumn<String>(
    'bangumi_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalSizeMeta = const VerificationMeta(
    'totalSize',
  );
  @override
  late final GeneratedColumn<int> totalSize = GeneratedColumn<int>(
    'total_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadedMeta = const VerificationMeta(
    'downloaded',
  );
  @override
  late final GeneratedColumn<int> downloaded = GeneratedColumn<int>(
    'downloaded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    infoHash,
    magnet,
    name,
    animeName,
    bangumiId,
    episodeNumber,
    status,
    filePath,
    totalSize,
    downloaded,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_download_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDownloadRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('info_hash')) {
      context.handle(
        _infoHashMeta,
        infoHash.isAcceptableOrUnknown(data['info_hash']!, _infoHashMeta),
      );
    } else if (isInserting) {
      context.missing(_infoHashMeta);
    }
    if (data.containsKey('magnet')) {
      context.handle(
        _magnetMeta,
        magnet.isAcceptableOrUnknown(data['magnet']!, _magnetMeta),
      );
    } else if (isInserting) {
      context.missing(_magnetMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('anime_name')) {
      context.handle(
        _animeNameMeta,
        animeName.isAcceptableOrUnknown(data['anime_name']!, _animeNameMeta),
      );
    }
    if (data.containsKey('bangumi_id')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumi_id']!, _bangumiIdMeta),
      );
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('total_size')) {
      context.handle(
        _totalSizeMeta,
        totalSize.isAcceptableOrUnknown(data['total_size']!, _totalSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_totalSizeMeta);
    }
    if (data.containsKey('downloaded')) {
      context.handle(
        _downloadedMeta,
        downloaded.isAcceptableOrUnknown(data['downloaded']!, _downloadedMeta),
      );
    } else if (isInserting) {
      context.missing(_downloadedMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbDownloadRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDownloadRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      infoHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info_hash'],
      )!,
      magnet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}magnet'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      animeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_name'],
      ),
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bangumi_id'],
      ),
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      totalSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_size'],
      )!,
      downloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DbDownloadRecordsTable createAlias(String alias) {
    return $DbDownloadRecordsTable(attachedDatabase, alias);
  }
}

class DbDownloadRecord extends DataClass
    implements Insertable<DbDownloadRecord> {
  final int id;
  final String infoHash;
  final String magnet;
  final String? name;
  final String? animeName;
  final String? bangumiId;
  final int? episodeNumber;
  final int status;
  final String? filePath;
  final int totalSize;
  final int downloaded;
  final int createdAt;
  final int updatedAt;
  const DbDownloadRecord({
    required this.id,
    required this.infoHash,
    required this.magnet,
    this.name,
    this.animeName,
    this.bangumiId,
    this.episodeNumber,
    required this.status,
    this.filePath,
    required this.totalSize,
    required this.downloaded,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['info_hash'] = Variable<String>(infoHash);
    map['magnet'] = Variable<String>(magnet);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || animeName != null) {
      map['anime_name'] = Variable<String>(animeName);
    }
    if (!nullToAbsent || bangumiId != null) {
      map['bangumi_id'] = Variable<String>(bangumiId);
    }
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<int>(episodeNumber);
    }
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['total_size'] = Variable<int>(totalSize);
    map['downloaded'] = Variable<int>(downloaded);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DbDownloadRecordsCompanion toCompanion(bool nullToAbsent) {
    return DbDownloadRecordsCompanion(
      id: Value(id),
      infoHash: Value(infoHash),
      magnet: Value(magnet),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      animeName: animeName == null && nullToAbsent
          ? const Value.absent()
          : Value(animeName),
      bangumiId: bangumiId == null && nullToAbsent
          ? const Value.absent()
          : Value(bangumiId),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
      status: Value(status),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      totalSize: Value(totalSize),
      downloaded: Value(downloaded),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbDownloadRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDownloadRecord(
      id: serializer.fromJson<int>(json['id']),
      infoHash: serializer.fromJson<String>(json['infoHash']),
      magnet: serializer.fromJson<String>(json['magnet']),
      name: serializer.fromJson<String?>(json['name']),
      animeName: serializer.fromJson<String?>(json['animeName']),
      bangumiId: serializer.fromJson<String?>(json['bangumiId']),
      episodeNumber: serializer.fromJson<int?>(json['episodeNumber']),
      status: serializer.fromJson<int>(json['status']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      totalSize: serializer.fromJson<int>(json['totalSize']),
      downloaded: serializer.fromJson<int>(json['downloaded']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'infoHash': serializer.toJson<String>(infoHash),
      'magnet': serializer.toJson<String>(magnet),
      'name': serializer.toJson<String?>(name),
      'animeName': serializer.toJson<String?>(animeName),
      'bangumiId': serializer.toJson<String?>(bangumiId),
      'episodeNumber': serializer.toJson<int?>(episodeNumber),
      'status': serializer.toJson<int>(status),
      'filePath': serializer.toJson<String?>(filePath),
      'totalSize': serializer.toJson<int>(totalSize),
      'downloaded': serializer.toJson<int>(downloaded),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DbDownloadRecord copyWith({
    int? id,
    String? infoHash,
    String? magnet,
    Value<String?> name = const Value.absent(),
    Value<String?> animeName = const Value.absent(),
    Value<String?> bangumiId = const Value.absent(),
    Value<int?> episodeNumber = const Value.absent(),
    int? status,
    Value<String?> filePath = const Value.absent(),
    int? totalSize,
    int? downloaded,
    int? createdAt,
    int? updatedAt,
  }) => DbDownloadRecord(
    id: id ?? this.id,
    infoHash: infoHash ?? this.infoHash,
    magnet: magnet ?? this.magnet,
    name: name.present ? name.value : this.name,
    animeName: animeName.present ? animeName.value : this.animeName,
    bangumiId: bangumiId.present ? bangumiId.value : this.bangumiId,
    episodeNumber: episodeNumber.present
        ? episodeNumber.value
        : this.episodeNumber,
    status: status ?? this.status,
    filePath: filePath.present ? filePath.value : this.filePath,
    totalSize: totalSize ?? this.totalSize,
    downloaded: downloaded ?? this.downloaded,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbDownloadRecord copyWithCompanion(DbDownloadRecordsCompanion data) {
    return DbDownloadRecord(
      id: data.id.present ? data.id.value : this.id,
      infoHash: data.infoHash.present ? data.infoHash.value : this.infoHash,
      magnet: data.magnet.present ? data.magnet.value : this.magnet,
      name: data.name.present ? data.name.value : this.name,
      animeName: data.animeName.present ? data.animeName.value : this.animeName,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      status: data.status.present ? data.status.value : this.status,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      totalSize: data.totalSize.present ? data.totalSize.value : this.totalSize,
      downloaded: data.downloaded.present
          ? data.downloaded.value
          : this.downloaded,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDownloadRecord(')
          ..write('id: $id, ')
          ..write('infoHash: $infoHash, ')
          ..write('magnet: $magnet, ')
          ..write('name: $name, ')
          ..write('animeName: $animeName, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('status: $status, ')
          ..write('filePath: $filePath, ')
          ..write('totalSize: $totalSize, ')
          ..write('downloaded: $downloaded, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    infoHash,
    magnet,
    name,
    animeName,
    bangumiId,
    episodeNumber,
    status,
    filePath,
    totalSize,
    downloaded,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDownloadRecord &&
          other.id == this.id &&
          other.infoHash == this.infoHash &&
          other.magnet == this.magnet &&
          other.name == this.name &&
          other.animeName == this.animeName &&
          other.bangumiId == this.bangumiId &&
          other.episodeNumber == this.episodeNumber &&
          other.status == this.status &&
          other.filePath == this.filePath &&
          other.totalSize == this.totalSize &&
          other.downloaded == this.downloaded &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DbDownloadRecordsCompanion extends UpdateCompanion<DbDownloadRecord> {
  final Value<int> id;
  final Value<String> infoHash;
  final Value<String> magnet;
  final Value<String?> name;
  final Value<String?> animeName;
  final Value<String?> bangumiId;
  final Value<int?> episodeNumber;
  final Value<int> status;
  final Value<String?> filePath;
  final Value<int> totalSize;
  final Value<int> downloaded;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const DbDownloadRecordsCompanion({
    this.id = const Value.absent(),
    this.infoHash = const Value.absent(),
    this.magnet = const Value.absent(),
    this.name = const Value.absent(),
    this.animeName = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.filePath = const Value.absent(),
    this.totalSize = const Value.absent(),
    this.downloaded = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DbDownloadRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String infoHash,
    required String magnet,
    this.name = const Value.absent(),
    this.animeName = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    required int status,
    this.filePath = const Value.absent(),
    required int totalSize,
    required int downloaded,
    required int createdAt,
    required int updatedAt,
  }) : infoHash = Value(infoHash),
       magnet = Value(magnet),
       status = Value(status),
       totalSize = Value(totalSize),
       downloaded = Value(downloaded),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DbDownloadRecord> custom({
    Expression<int>? id,
    Expression<String>? infoHash,
    Expression<String>? magnet,
    Expression<String>? name,
    Expression<String>? animeName,
    Expression<String>? bangumiId,
    Expression<int>? episodeNumber,
    Expression<int>? status,
    Expression<String>? filePath,
    Expression<int>? totalSize,
    Expression<int>? downloaded,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (infoHash != null) 'info_hash': infoHash,
      if (magnet != null) 'magnet': magnet,
      if (name != null) 'name': name,
      if (animeName != null) 'anime_name': animeName,
      if (bangumiId != null) 'bangumi_id': bangumiId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (status != null) 'status': status,
      if (filePath != null) 'file_path': filePath,
      if (totalSize != null) 'total_size': totalSize,
      if (downloaded != null) 'downloaded': downloaded,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DbDownloadRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? infoHash,
    Value<String>? magnet,
    Value<String?>? name,
    Value<String?>? animeName,
    Value<String?>? bangumiId,
    Value<int?>? episodeNumber,
    Value<int>? status,
    Value<String?>? filePath,
    Value<int>? totalSize,
    Value<int>? downloaded,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return DbDownloadRecordsCompanion(
      id: id ?? this.id,
      infoHash: infoHash ?? this.infoHash,
      magnet: magnet ?? this.magnet,
      name: name ?? this.name,
      animeName: animeName ?? this.animeName,
      bangumiId: bangumiId ?? this.bangumiId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      totalSize: totalSize ?? this.totalSize,
      downloaded: downloaded ?? this.downloaded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (infoHash.present) {
      map['info_hash'] = Variable<String>(infoHash.value);
    }
    if (magnet.present) {
      map['magnet'] = Variable<String>(magnet.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (animeName.present) {
      map['anime_name'] = Variable<String>(animeName.value);
    }
    if (bangumiId.present) {
      map['bangumi_id'] = Variable<String>(bangumiId.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (totalSize.present) {
      map['total_size'] = Variable<int>(totalSize.value);
    }
    if (downloaded.present) {
      map['downloaded'] = Variable<int>(downloaded.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbDownloadRecordsCompanion(')
          ..write('id: $id, ')
          ..write('infoHash: $infoHash, ')
          ..write('magnet: $magnet, ')
          ..write('name: $name, ')
          ..write('animeName: $animeName, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('status: $status, ')
          ..write('filePath: $filePath, ')
          ..write('totalSize: $totalSize, ')
          ..write('downloaded: $downloaded, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DbLocalFavoritesTable dbLocalFavorites = $DbLocalFavoritesTable(
    this,
  );
  late final $DbBangumiSyncQueueTable dbBangumiSyncQueue =
      $DbBangumiSyncQueueTable(this);
  late final $DbBangumiSubjectCachesTable dbBangumiSubjectCaches =
      $DbBangumiSubjectCachesTable(this);
  late final $DbBangumiCharacterCachesTable dbBangumiCharacterCaches =
      $DbBangumiCharacterCachesTable(this);
  late final $DbBangumiRelationCachesTable dbBangumiRelationCaches =
      $DbBangumiRelationCachesTable(this);
  late final $DbTimetableCachesTable dbTimetableCaches =
      $DbTimetableCachesTable(this);
  late final $DbRankingCachesTable dbRankingCaches = $DbRankingCachesTable(
    this,
  );
  late final $DbBangumiEpisodeCachesTable dbBangumiEpisodeCaches =
      $DbBangumiEpisodeCachesTable(this);
  late final $DbBangumiPersonCachesTable dbBangumiPersonCaches =
      $DbBangumiPersonCachesTable(this);
  late final $DbDownloadRecordsTable dbDownloadRecords =
      $DbDownloadRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dbLocalFavorites,
    dbBangumiSyncQueue,
    dbBangumiSubjectCaches,
    dbBangumiCharacterCaches,
    dbBangumiRelationCaches,
    dbTimetableCaches,
    dbRankingCaches,
    dbBangumiEpisodeCaches,
    dbBangumiPersonCaches,
    dbDownloadRecords,
  ];
}

typedef $$DbLocalFavoritesTableCreateCompanionBuilder =
    DbLocalFavoritesCompanion Function({
      Value<int> id,
      required int bangumiId,
      required String title,
      required String coverUrl,
      required int type,
      required double score,
      required int createdAt,
      Value<int?> rate,
      Value<String?> comment,
      Value<String?> tagsJson,
      Value<bool?> private,
      Value<int?> updatedAt,
      Value<int?> baseType,
      Value<int?> baseRate,
      Value<String?> baseComment,
      Value<String?> baseTagsJson,
      Value<bool?> basePrivate,
      Value<String?> remoteUpdatedAt,
      Value<int?> lastSyncedAt,
      Value<int?> ownerAccountId,
    });
typedef $$DbLocalFavoritesTableUpdateCompanionBuilder =
    DbLocalFavoritesCompanion Function({
      Value<int> id,
      Value<int> bangumiId,
      Value<String> title,
      Value<String> coverUrl,
      Value<int> type,
      Value<double> score,
      Value<int> createdAt,
      Value<int?> rate,
      Value<String?> comment,
      Value<String?> tagsJson,
      Value<bool?> private,
      Value<int?> updatedAt,
      Value<int?> baseType,
      Value<int?> baseRate,
      Value<String?> baseComment,
      Value<String?> baseTagsJson,
      Value<bool?> basePrivate,
      Value<String?> remoteUpdatedAt,
      Value<int?> lastSyncedAt,
      Value<int?> ownerAccountId,
    });

class $$DbLocalFavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $DbLocalFavoritesTable> {
  $$DbLocalFavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseType => $composableBuilder(
    column: $table.baseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRate => $composableBuilder(
    column: $table.baseRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseComment => $composableBuilder(
    column: $table.baseComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseTagsJson => $composableBuilder(
    column: $table.baseTagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get basePrivate => $composableBuilder(
    column: $table.basePrivate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownerAccountId => $composableBuilder(
    column: $table.ownerAccountId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbLocalFavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbLocalFavoritesTable> {
  $$DbLocalFavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get private => $composableBuilder(
    column: $table.private,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseType => $composableBuilder(
    column: $table.baseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRate => $composableBuilder(
    column: $table.baseRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseComment => $composableBuilder(
    column: $table.baseComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseTagsJson => $composableBuilder(
    column: $table.baseTagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get basePrivate => $composableBuilder(
    column: $table.basePrivate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownerAccountId => $composableBuilder(
    column: $table.ownerAccountId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbLocalFavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbLocalFavoritesTable> {
  $$DbLocalFavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<bool> get private =>
      $composableBuilder(column: $table.private, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get baseType =>
      $composableBuilder(column: $table.baseType, builder: (column) => column);

  GeneratedColumn<int> get baseRate =>
      $composableBuilder(column: $table.baseRate, builder: (column) => column);

  GeneratedColumn<String> get baseComment => $composableBuilder(
    column: $table.baseComment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseTagsJson => $composableBuilder(
    column: $table.baseTagsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get basePrivate => $composableBuilder(
    column: $table.basePrivate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ownerAccountId => $composableBuilder(
    column: $table.ownerAccountId,
    builder: (column) => column,
  );
}

class $$DbLocalFavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbLocalFavoritesTable,
          DbLocalFavorite,
          $$DbLocalFavoritesTableFilterComposer,
          $$DbLocalFavoritesTableOrderingComposer,
          $$DbLocalFavoritesTableAnnotationComposer,
          $$DbLocalFavoritesTableCreateCompanionBuilder,
          $$DbLocalFavoritesTableUpdateCompanionBuilder,
          (
            DbLocalFavorite,
            BaseReferences<
              _$AppDatabase,
              $DbLocalFavoritesTable,
              DbLocalFavorite
            >,
          ),
          DbLocalFavorite,
          PrefetchHooks Function()
        > {
  $$DbLocalFavoritesTableTableManager(
    _$AppDatabase db,
    $DbLocalFavoritesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbLocalFavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbLocalFavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbLocalFavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bangumiId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> rate = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<bool?> private = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int?> baseType = const Value.absent(),
                Value<int?> baseRate = const Value.absent(),
                Value<String?> baseComment = const Value.absent(),
                Value<String?> baseTagsJson = const Value.absent(),
                Value<bool?> basePrivate = const Value.absent(),
                Value<String?> remoteUpdatedAt = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<int?> ownerAccountId = const Value.absent(),
              }) => DbLocalFavoritesCompanion(
                id: id,
                bangumiId: bangumiId,
                title: title,
                coverUrl: coverUrl,
                type: type,
                score: score,
                createdAt: createdAt,
                rate: rate,
                comment: comment,
                tagsJson: tagsJson,
                private: private,
                updatedAt: updatedAt,
                baseType: baseType,
                baseRate: baseRate,
                baseComment: baseComment,
                baseTagsJson: baseTagsJson,
                basePrivate: basePrivate,
                remoteUpdatedAt: remoteUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                ownerAccountId: ownerAccountId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bangumiId,
                required String title,
                required String coverUrl,
                required int type,
                required double score,
                required int createdAt,
                Value<int?> rate = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<bool?> private = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int?> baseType = const Value.absent(),
                Value<int?> baseRate = const Value.absent(),
                Value<String?> baseComment = const Value.absent(),
                Value<String?> baseTagsJson = const Value.absent(),
                Value<bool?> basePrivate = const Value.absent(),
                Value<String?> remoteUpdatedAt = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<int?> ownerAccountId = const Value.absent(),
              }) => DbLocalFavoritesCompanion.insert(
                id: id,
                bangumiId: bangumiId,
                title: title,
                coverUrl: coverUrl,
                type: type,
                score: score,
                createdAt: createdAt,
                rate: rate,
                comment: comment,
                tagsJson: tagsJson,
                private: private,
                updatedAt: updatedAt,
                baseType: baseType,
                baseRate: baseRate,
                baseComment: baseComment,
                baseTagsJson: baseTagsJson,
                basePrivate: basePrivate,
                remoteUpdatedAt: remoteUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                ownerAccountId: ownerAccountId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbLocalFavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbLocalFavoritesTable,
      DbLocalFavorite,
      $$DbLocalFavoritesTableFilterComposer,
      $$DbLocalFavoritesTableOrderingComposer,
      $$DbLocalFavoritesTableAnnotationComposer,
      $$DbLocalFavoritesTableCreateCompanionBuilder,
      $$DbLocalFavoritesTableUpdateCompanionBuilder,
      (
        DbLocalFavorite,
        BaseReferences<_$AppDatabase, $DbLocalFavoritesTable, DbLocalFavorite>,
      ),
      DbLocalFavorite,
      PrefetchHooks Function()
    >;
typedef $$DbBangumiSyncQueueTableCreateCompanionBuilder =
    DbBangumiSyncQueueCompanion Function({
      Value<int> id,
      required int accountId,
      required int subjectId,
      required String operation,
      required String payloadJson,
      Value<String?> baselineJson,
      Value<int> attemptCount,
      Value<int> nextAttemptAt,
      Value<String?> lastError,
      required int createdAt,
      required int updatedAt,
    });
typedef $$DbBangumiSyncQueueTableUpdateCompanionBuilder =
    DbBangumiSyncQueueCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<int> subjectId,
      Value<String> operation,
      Value<String> payloadJson,
      Value<String?> baselineJson,
      Value<int> attemptCount,
      Value<int> nextAttemptAt,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

class $$DbBangumiSyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $DbBangumiSyncQueueTable> {
  $$DbBangumiSyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baselineJson => $composableBuilder(
    column: $table.baselineJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbBangumiSyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $DbBangumiSyncQueueTable> {
  $$DbBangumiSyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baselineJson => $composableBuilder(
    column: $table.baselineJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbBangumiSyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbBangumiSyncQueueTable> {
  $$DbBangumiSyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baselineJson => $composableBuilder(
    column: $table.baselineJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DbBangumiSyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbBangumiSyncQueueTable,
          DbBangumiSyncQueueData,
          $$DbBangumiSyncQueueTableFilterComposer,
          $$DbBangumiSyncQueueTableOrderingComposer,
          $$DbBangumiSyncQueueTableAnnotationComposer,
          $$DbBangumiSyncQueueTableCreateCompanionBuilder,
          $$DbBangumiSyncQueueTableUpdateCompanionBuilder,
          (
            DbBangumiSyncQueueData,
            BaseReferences<
              _$AppDatabase,
              $DbBangumiSyncQueueTable,
              DbBangumiSyncQueueData
            >,
          ),
          DbBangumiSyncQueueData,
          PrefetchHooks Function()
        > {
  $$DbBangumiSyncQueueTableTableManager(
    _$AppDatabase db,
    $DbBangumiSyncQueueTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbBangumiSyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbBangumiSyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbBangumiSyncQueueTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> baselineJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => DbBangumiSyncQueueCompanion(
                id: id,
                accountId: accountId,
                subjectId: subjectId,
                operation: operation,
                payloadJson: payloadJson,
                baselineJson: baselineJson,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required int subjectId,
                required String operation,
                required String payloadJson,
                Value<String?> baselineJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => DbBangumiSyncQueueCompanion.insert(
                id: id,
                accountId: accountId,
                subjectId: subjectId,
                operation: operation,
                payloadJson: payloadJson,
                baselineJson: baselineJson,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbBangumiSyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbBangumiSyncQueueTable,
      DbBangumiSyncQueueData,
      $$DbBangumiSyncQueueTableFilterComposer,
      $$DbBangumiSyncQueueTableOrderingComposer,
      $$DbBangumiSyncQueueTableAnnotationComposer,
      $$DbBangumiSyncQueueTableCreateCompanionBuilder,
      $$DbBangumiSyncQueueTableUpdateCompanionBuilder,
      (
        DbBangumiSyncQueueData,
        BaseReferences<
          _$AppDatabase,
          $DbBangumiSyncQueueTable,
          DbBangumiSyncQueueData
        >,
      ),
      DbBangumiSyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$DbBangumiSubjectCachesTableCreateCompanionBuilder =
    DbBangumiSubjectCachesCompanion Function({
      Value<int> id,
      required int bangumiId,
      required String title,
      Value<String?> titleCn,
      Value<String?> originalTitle,
      Value<String?> description,
      Value<double?> score,
      Value<int?> rank,
      Value<String?> imageSmall,
      Value<String?> imageGrid,
      Value<String?> imageLarge,
      Value<String?> imageMedium,
      Value<String?> imageCommon,
      Value<String?> localImagePath,
      Value<String?> airDate,
      Value<String?> airWeekday,
      Value<String?> tagsJson,
      Value<String?> fullJson,
      Value<int?> type,
      Value<int?> totalEpisodes,
      required int cachedAt,
      required int expiresAt,
    });
typedef $$DbBangumiSubjectCachesTableUpdateCompanionBuilder =
    DbBangumiSubjectCachesCompanion Function({
      Value<int> id,
      Value<int> bangumiId,
      Value<String> title,
      Value<String?> titleCn,
      Value<String?> originalTitle,
      Value<String?> description,
      Value<double?> score,
      Value<int?> rank,
      Value<String?> imageSmall,
      Value<String?> imageGrid,
      Value<String?> imageLarge,
      Value<String?> imageMedium,
      Value<String?> imageCommon,
      Value<String?> localImagePath,
      Value<String?> airDate,
      Value<String?> airWeekday,
      Value<String?> tagsJson,
      Value<String?> fullJson,
      Value<int?> type,
      Value<int?> totalEpisodes,
      Value<int> cachedAt,
      Value<int> expiresAt,
    });

class $$DbBangumiSubjectCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DbBangumiSubjectCachesTable> {
  $$DbBangumiSubjectCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleCn => $composableBuilder(
    column: $table.titleCn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageGrid => $composableBuilder(
    column: $table.imageGrid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageMedium => $composableBuilder(
    column: $table.imageMedium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageCommon => $composableBuilder(
    column: $table.imageCommon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullJson => $composableBuilder(
    column: $table.fullJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbBangumiSubjectCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbBangumiSubjectCachesTable> {
  $$DbBangumiSubjectCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleCn => $composableBuilder(
    column: $table.titleCn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageGrid => $composableBuilder(
    column: $table.imageGrid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageMedium => $composableBuilder(
    column: $table.imageMedium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageCommon => $composableBuilder(
    column: $table.imageCommon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullJson => $composableBuilder(
    column: $table.fullJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbBangumiSubjectCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbBangumiSubjectCachesTable> {
  $$DbBangumiSubjectCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleCn =>
      $composableBuilder(column: $table.titleCn, builder: (column) => column);

  GeneratedColumn<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageGrid =>
      $composableBuilder(column: $table.imageGrid, builder: (column) => column);

  GeneratedColumn<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageMedium => $composableBuilder(
    column: $table.imageMedium,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageCommon => $composableBuilder(
    column: $table.imageCommon,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  GeneratedColumn<String> get airWeekday => $composableBuilder(
    column: $table.airWeekday,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get fullJson =>
      $composableBuilder(column: $table.fullJson, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$DbBangumiSubjectCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbBangumiSubjectCachesTable,
          DbBangumiSubjectCache,
          $$DbBangumiSubjectCachesTableFilterComposer,
          $$DbBangumiSubjectCachesTableOrderingComposer,
          $$DbBangumiSubjectCachesTableAnnotationComposer,
          $$DbBangumiSubjectCachesTableCreateCompanionBuilder,
          $$DbBangumiSubjectCachesTableUpdateCompanionBuilder,
          (
            DbBangumiSubjectCache,
            BaseReferences<
              _$AppDatabase,
              $DbBangumiSubjectCachesTable,
              DbBangumiSubjectCache
            >,
          ),
          DbBangumiSubjectCache,
          PrefetchHooks Function()
        > {
  $$DbBangumiSubjectCachesTableTableManager(
    _$AppDatabase db,
    $DbBangumiSubjectCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbBangumiSubjectCachesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DbBangumiSubjectCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DbBangumiSubjectCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bangumiId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> titleCn = const Value.absent(),
                Value<String?> originalTitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageGrid = const Value.absent(),
                Value<String?> imageLarge = const Value.absent(),
                Value<String?> imageMedium = const Value.absent(),
                Value<String?> imageCommon = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<String?> airWeekday = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<String?> fullJson = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
              }) => DbBangumiSubjectCachesCompanion(
                id: id,
                bangumiId: bangumiId,
                title: title,
                titleCn: titleCn,
                originalTitle: originalTitle,
                description: description,
                score: score,
                rank: rank,
                imageSmall: imageSmall,
                imageGrid: imageGrid,
                imageLarge: imageLarge,
                imageMedium: imageMedium,
                imageCommon: imageCommon,
                localImagePath: localImagePath,
                airDate: airDate,
                airWeekday: airWeekday,
                tagsJson: tagsJson,
                fullJson: fullJson,
                type: type,
                totalEpisodes: totalEpisodes,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bangumiId,
                required String title,
                Value<String?> titleCn = const Value.absent(),
                Value<String?> originalTitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageGrid = const Value.absent(),
                Value<String?> imageLarge = const Value.absent(),
                Value<String?> imageMedium = const Value.absent(),
                Value<String?> imageCommon = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<String?> airWeekday = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<String?> fullJson = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                required int cachedAt,
                required int expiresAt,
              }) => DbBangumiSubjectCachesCompanion.insert(
                id: id,
                bangumiId: bangumiId,
                title: title,
                titleCn: titleCn,
                originalTitle: originalTitle,
                description: description,
                score: score,
                rank: rank,
                imageSmall: imageSmall,
                imageGrid: imageGrid,
                imageLarge: imageLarge,
                imageMedium: imageMedium,
                imageCommon: imageCommon,
                localImagePath: localImagePath,
                airDate: airDate,
                airWeekday: airWeekday,
                tagsJson: tagsJson,
                fullJson: fullJson,
                type: type,
                totalEpisodes: totalEpisodes,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbBangumiSubjectCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbBangumiSubjectCachesTable,
      DbBangumiSubjectCache,
      $$DbBangumiSubjectCachesTableFilterComposer,
      $$DbBangumiSubjectCachesTableOrderingComposer,
      $$DbBangumiSubjectCachesTableAnnotationComposer,
      $$DbBangumiSubjectCachesTableCreateCompanionBuilder,
      $$DbBangumiSubjectCachesTableUpdateCompanionBuilder,
      (
        DbBangumiSubjectCache,
        BaseReferences<
          _$AppDatabase,
          $DbBangumiSubjectCachesTable,
          DbBangumiSubjectCache
        >,
      ),
      DbBangumiSubjectCache,
      PrefetchHooks Function()
    >;
typedef $$DbBangumiCharacterCachesTableCreateCompanionBuilder =
    DbBangumiCharacterCachesCompanion Function({
      Value<int> id,
      required int subjectId,
      required int characterId,
      required String name,
      required String roleName,
      Value<String?> imageSmall,
      Value<String?> imageGrid,
      Value<String?> imageLarge,
      Value<String?> imageMedium,
      Value<String?> imageCommon,
      Value<String?> localImagePath,
      Value<String?> actorsJson,
      required int cachedAt,
      required int expiresAt,
    });
typedef $$DbBangumiCharacterCachesTableUpdateCompanionBuilder =
    DbBangumiCharacterCachesCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<int> characterId,
      Value<String> name,
      Value<String> roleName,
      Value<String?> imageSmall,
      Value<String?> imageGrid,
      Value<String?> imageLarge,
      Value<String?> imageMedium,
      Value<String?> imageCommon,
      Value<String?> localImagePath,
      Value<String?> actorsJson,
      Value<int> cachedAt,
      Value<int> expiresAt,
    });

class $$DbBangumiCharacterCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DbBangumiCharacterCachesTable> {
  $$DbBangumiCharacterCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleName => $composableBuilder(
    column: $table.roleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageGrid => $composableBuilder(
    column: $table.imageGrid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageMedium => $composableBuilder(
    column: $table.imageMedium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageCommon => $composableBuilder(
    column: $table.imageCommon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorsJson => $composableBuilder(
    column: $table.actorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbBangumiCharacterCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbBangumiCharacterCachesTable> {
  $$DbBangumiCharacterCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleName => $composableBuilder(
    column: $table.roleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageGrid => $composableBuilder(
    column: $table.imageGrid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageMedium => $composableBuilder(
    column: $table.imageMedium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageCommon => $composableBuilder(
    column: $table.imageCommon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorsJson => $composableBuilder(
    column: $table.actorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbBangumiCharacterCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbBangumiCharacterCachesTable> {
  $$DbBangumiCharacterCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get roleName =>
      $composableBuilder(column: $table.roleName, builder: (column) => column);

  GeneratedColumn<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageGrid =>
      $composableBuilder(column: $table.imageGrid, builder: (column) => column);

  GeneratedColumn<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageMedium => $composableBuilder(
    column: $table.imageMedium,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageCommon => $composableBuilder(
    column: $table.imageCommon,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorsJson => $composableBuilder(
    column: $table.actorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$DbBangumiCharacterCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbBangumiCharacterCachesTable,
          DbBangumiCharacterCache,
          $$DbBangumiCharacterCachesTableFilterComposer,
          $$DbBangumiCharacterCachesTableOrderingComposer,
          $$DbBangumiCharacterCachesTableAnnotationComposer,
          $$DbBangumiCharacterCachesTableCreateCompanionBuilder,
          $$DbBangumiCharacterCachesTableUpdateCompanionBuilder,
          (
            DbBangumiCharacterCache,
            BaseReferences<
              _$AppDatabase,
              $DbBangumiCharacterCachesTable,
              DbBangumiCharacterCache
            >,
          ),
          DbBangumiCharacterCache,
          PrefetchHooks Function()
        > {
  $$DbBangumiCharacterCachesTableTableManager(
    _$AppDatabase db,
    $DbBangumiCharacterCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbBangumiCharacterCachesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DbBangumiCharacterCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DbBangumiCharacterCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<int> characterId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> roleName = const Value.absent(),
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageGrid = const Value.absent(),
                Value<String?> imageLarge = const Value.absent(),
                Value<String?> imageMedium = const Value.absent(),
                Value<String?> imageCommon = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
                Value<String?> actorsJson = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
              }) => DbBangumiCharacterCachesCompanion(
                id: id,
                subjectId: subjectId,
                characterId: characterId,
                name: name,
                roleName: roleName,
                imageSmall: imageSmall,
                imageGrid: imageGrid,
                imageLarge: imageLarge,
                imageMedium: imageMedium,
                imageCommon: imageCommon,
                localImagePath: localImagePath,
                actorsJson: actorsJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required int characterId,
                required String name,
                required String roleName,
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageGrid = const Value.absent(),
                Value<String?> imageLarge = const Value.absent(),
                Value<String?> imageMedium = const Value.absent(),
                Value<String?> imageCommon = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
                Value<String?> actorsJson = const Value.absent(),
                required int cachedAt,
                required int expiresAt,
              }) => DbBangumiCharacterCachesCompanion.insert(
                id: id,
                subjectId: subjectId,
                characterId: characterId,
                name: name,
                roleName: roleName,
                imageSmall: imageSmall,
                imageGrid: imageGrid,
                imageLarge: imageLarge,
                imageMedium: imageMedium,
                imageCommon: imageCommon,
                localImagePath: localImagePath,
                actorsJson: actorsJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbBangumiCharacterCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbBangumiCharacterCachesTable,
      DbBangumiCharacterCache,
      $$DbBangumiCharacterCachesTableFilterComposer,
      $$DbBangumiCharacterCachesTableOrderingComposer,
      $$DbBangumiCharacterCachesTableAnnotationComposer,
      $$DbBangumiCharacterCachesTableCreateCompanionBuilder,
      $$DbBangumiCharacterCachesTableUpdateCompanionBuilder,
      (
        DbBangumiCharacterCache,
        BaseReferences<
          _$AppDatabase,
          $DbBangumiCharacterCachesTable,
          DbBangumiCharacterCache
        >,
      ),
      DbBangumiCharacterCache,
      PrefetchHooks Function()
    >;
typedef $$DbBangumiRelationCachesTableCreateCompanionBuilder =
    DbBangumiRelationCachesCompanion Function({
      Value<int> id,
      required int sourceSubjectId,
      required int relatedSubjectId,
      required String name,
      Value<String?> nameCn,
      required String relation,
      Value<String?> imageUrl,
      Value<String?> localImagePath,
      required int cachedAt,
      required int expiresAt,
    });
typedef $$DbBangumiRelationCachesTableUpdateCompanionBuilder =
    DbBangumiRelationCachesCompanion Function({
      Value<int> id,
      Value<int> sourceSubjectId,
      Value<int> relatedSubjectId,
      Value<String> name,
      Value<String?> nameCn,
      Value<String> relation,
      Value<String?> imageUrl,
      Value<String?> localImagePath,
      Value<int> cachedAt,
      Value<int> expiresAt,
    });

class $$DbBangumiRelationCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DbBangumiRelationCachesTable> {
  $$DbBangumiRelationCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceSubjectId => $composableBuilder(
    column: $table.sourceSubjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get relatedSubjectId => $composableBuilder(
    column: $table.relatedSubjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbBangumiRelationCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbBangumiRelationCachesTable> {
  $$DbBangumiRelationCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceSubjectId => $composableBuilder(
    column: $table.sourceSubjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get relatedSubjectId => $composableBuilder(
    column: $table.relatedSubjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameCn => $composableBuilder(
    column: $table.nameCn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbBangumiRelationCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbBangumiRelationCachesTable> {
  $$DbBangumiRelationCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sourceSubjectId => $composableBuilder(
    column: $table.sourceSubjectId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get relatedSubjectId => $composableBuilder(
    column: $table.relatedSubjectId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameCn =>
      $composableBuilder(column: $table.nameCn, builder: (column) => column);

  GeneratedColumn<String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$DbBangumiRelationCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbBangumiRelationCachesTable,
          DbBangumiRelationCache,
          $$DbBangumiRelationCachesTableFilterComposer,
          $$DbBangumiRelationCachesTableOrderingComposer,
          $$DbBangumiRelationCachesTableAnnotationComposer,
          $$DbBangumiRelationCachesTableCreateCompanionBuilder,
          $$DbBangumiRelationCachesTableUpdateCompanionBuilder,
          (
            DbBangumiRelationCache,
            BaseReferences<
              _$AppDatabase,
              $DbBangumiRelationCachesTable,
              DbBangumiRelationCache
            >,
          ),
          DbBangumiRelationCache,
          PrefetchHooks Function()
        > {
  $$DbBangumiRelationCachesTableTableManager(
    _$AppDatabase db,
    $DbBangumiRelationCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbBangumiRelationCachesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DbBangumiRelationCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DbBangumiRelationCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sourceSubjectId = const Value.absent(),
                Value<int> relatedSubjectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nameCn = const Value.absent(),
                Value<String> relation = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
              }) => DbBangumiRelationCachesCompanion(
                id: id,
                sourceSubjectId: sourceSubjectId,
                relatedSubjectId: relatedSubjectId,
                name: name,
                nameCn: nameCn,
                relation: relation,
                imageUrl: imageUrl,
                localImagePath: localImagePath,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sourceSubjectId,
                required int relatedSubjectId,
                required String name,
                Value<String?> nameCn = const Value.absent(),
                required String relation,
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
                required int cachedAt,
                required int expiresAt,
              }) => DbBangumiRelationCachesCompanion.insert(
                id: id,
                sourceSubjectId: sourceSubjectId,
                relatedSubjectId: relatedSubjectId,
                name: name,
                nameCn: nameCn,
                relation: relation,
                imageUrl: imageUrl,
                localImagePath: localImagePath,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbBangumiRelationCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbBangumiRelationCachesTable,
      DbBangumiRelationCache,
      $$DbBangumiRelationCachesTableFilterComposer,
      $$DbBangumiRelationCachesTableOrderingComposer,
      $$DbBangumiRelationCachesTableAnnotationComposer,
      $$DbBangumiRelationCachesTableCreateCompanionBuilder,
      $$DbBangumiRelationCachesTableUpdateCompanionBuilder,
      (
        DbBangumiRelationCache,
        BaseReferences<
          _$AppDatabase,
          $DbBangumiRelationCachesTable,
          DbBangumiRelationCache
        >,
      ),
      DbBangumiRelationCache,
      PrefetchHooks Function()
    >;
typedef $$DbTimetableCachesTableCreateCompanionBuilder =
    DbTimetableCachesCompanion Function({
      Value<int> id,
      required String quarter,
      required String animesJson,
      required int cachedAt,
      required int expiresAt,
    });
typedef $$DbTimetableCachesTableUpdateCompanionBuilder =
    DbTimetableCachesCompanion Function({
      Value<int> id,
      Value<String> quarter,
      Value<String> animesJson,
      Value<int> cachedAt,
      Value<int> expiresAt,
    });

class $$DbTimetableCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DbTimetableCachesTable> {
  $$DbTimetableCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quarter => $composableBuilder(
    column: $table.quarter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animesJson => $composableBuilder(
    column: $table.animesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbTimetableCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbTimetableCachesTable> {
  $$DbTimetableCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quarter => $composableBuilder(
    column: $table.quarter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animesJson => $composableBuilder(
    column: $table.animesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbTimetableCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbTimetableCachesTable> {
  $$DbTimetableCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get quarter =>
      $composableBuilder(column: $table.quarter, builder: (column) => column);

  GeneratedColumn<String> get animesJson => $composableBuilder(
    column: $table.animesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$DbTimetableCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbTimetableCachesTable,
          DbTimetableCache,
          $$DbTimetableCachesTableFilterComposer,
          $$DbTimetableCachesTableOrderingComposer,
          $$DbTimetableCachesTableAnnotationComposer,
          $$DbTimetableCachesTableCreateCompanionBuilder,
          $$DbTimetableCachesTableUpdateCompanionBuilder,
          (
            DbTimetableCache,
            BaseReferences<
              _$AppDatabase,
              $DbTimetableCachesTable,
              DbTimetableCache
            >,
          ),
          DbTimetableCache,
          PrefetchHooks Function()
        > {
  $$DbTimetableCachesTableTableManager(
    _$AppDatabase db,
    $DbTimetableCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbTimetableCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbTimetableCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbTimetableCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> quarter = const Value.absent(),
                Value<String> animesJson = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
              }) => DbTimetableCachesCompanion(
                id: id,
                quarter: quarter,
                animesJson: animesJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String quarter,
                required String animesJson,
                required int cachedAt,
                required int expiresAt,
              }) => DbTimetableCachesCompanion.insert(
                id: id,
                quarter: quarter,
                animesJson: animesJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbTimetableCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbTimetableCachesTable,
      DbTimetableCache,
      $$DbTimetableCachesTableFilterComposer,
      $$DbTimetableCachesTableOrderingComposer,
      $$DbTimetableCachesTableAnnotationComposer,
      $$DbTimetableCachesTableCreateCompanionBuilder,
      $$DbTimetableCachesTableUpdateCompanionBuilder,
      (
        DbTimetableCache,
        BaseReferences<
          _$AppDatabase,
          $DbTimetableCachesTable,
          DbTimetableCache
        >,
      ),
      DbTimetableCache,
      PrefetchHooks Function()
    >;
typedef $$DbRankingCachesTableCreateCompanionBuilder =
    DbRankingCachesCompanion Function({
      Value<int> id,
      required String cacheKey,
      required String sortType,
      Value<String?> year,
      Value<String?> tagsJson,
      required int page,
      required String resultsJson,
      required int cachedAt,
      required int expiresAt,
    });
typedef $$DbRankingCachesTableUpdateCompanionBuilder =
    DbRankingCachesCompanion Function({
      Value<int> id,
      Value<String> cacheKey,
      Value<String> sortType,
      Value<String?> year,
      Value<String?> tagsJson,
      Value<int> page,
      Value<String> resultsJson,
      Value<int> cachedAt,
      Value<int> expiresAt,
    });

class $$DbRankingCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DbRankingCachesTable> {
  $$DbRankingCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortType => $composableBuilder(
    column: $table.sortType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultsJson => $composableBuilder(
    column: $table.resultsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbRankingCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbRankingCachesTable> {
  $$DbRankingCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortType => $composableBuilder(
    column: $table.sortType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultsJson => $composableBuilder(
    column: $table.resultsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbRankingCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbRankingCachesTable> {
  $$DbRankingCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get sortType =>
      $composableBuilder(column: $table.sortType, builder: (column) => column);

  GeneratedColumn<String> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<String> get resultsJson => $composableBuilder(
    column: $table.resultsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$DbRankingCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbRankingCachesTable,
          DbRankingCache,
          $$DbRankingCachesTableFilterComposer,
          $$DbRankingCachesTableOrderingComposer,
          $$DbRankingCachesTableAnnotationComposer,
          $$DbRankingCachesTableCreateCompanionBuilder,
          $$DbRankingCachesTableUpdateCompanionBuilder,
          (
            DbRankingCache,
            BaseReferences<
              _$AppDatabase,
              $DbRankingCachesTable,
              DbRankingCache
            >,
          ),
          DbRankingCache,
          PrefetchHooks Function()
        > {
  $$DbRankingCachesTableTableManager(
    _$AppDatabase db,
    $DbRankingCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbRankingCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbRankingCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbRankingCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cacheKey = const Value.absent(),
                Value<String> sortType = const Value.absent(),
                Value<String?> year = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<String> resultsJson = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
              }) => DbRankingCachesCompanion(
                id: id,
                cacheKey: cacheKey,
                sortType: sortType,
                year: year,
                tagsJson: tagsJson,
                page: page,
                resultsJson: resultsJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String cacheKey,
                required String sortType,
                Value<String?> year = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                required int page,
                required String resultsJson,
                required int cachedAt,
                required int expiresAt,
              }) => DbRankingCachesCompanion.insert(
                id: id,
                cacheKey: cacheKey,
                sortType: sortType,
                year: year,
                tagsJson: tagsJson,
                page: page,
                resultsJson: resultsJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbRankingCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbRankingCachesTable,
      DbRankingCache,
      $$DbRankingCachesTableFilterComposer,
      $$DbRankingCachesTableOrderingComposer,
      $$DbRankingCachesTableAnnotationComposer,
      $$DbRankingCachesTableCreateCompanionBuilder,
      $$DbRankingCachesTableUpdateCompanionBuilder,
      (
        DbRankingCache,
        BaseReferences<_$AppDatabase, $DbRankingCachesTable, DbRankingCache>,
      ),
      DbRankingCache,
      PrefetchHooks Function()
    >;
typedef $$DbBangumiEpisodeCachesTableCreateCompanionBuilder =
    DbBangumiEpisodeCachesCompanion Function({
      Value<int> id,
      required int subjectId,
      required String episodesJson,
      required int cachedAt,
      required int expiresAt,
    });
typedef $$DbBangumiEpisodeCachesTableUpdateCompanionBuilder =
    DbBangumiEpisodeCachesCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> episodesJson,
      Value<int> cachedAt,
      Value<int> expiresAt,
    });

class $$DbBangumiEpisodeCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DbBangumiEpisodeCachesTable> {
  $$DbBangumiEpisodeCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodesJson => $composableBuilder(
    column: $table.episodesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbBangumiEpisodeCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbBangumiEpisodeCachesTable> {
  $$DbBangumiEpisodeCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodesJson => $composableBuilder(
    column: $table.episodesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbBangumiEpisodeCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbBangumiEpisodeCachesTable> {
  $$DbBangumiEpisodeCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get episodesJson => $composableBuilder(
    column: $table.episodesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$DbBangumiEpisodeCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbBangumiEpisodeCachesTable,
          DbBangumiEpisodeCache,
          $$DbBangumiEpisodeCachesTableFilterComposer,
          $$DbBangumiEpisodeCachesTableOrderingComposer,
          $$DbBangumiEpisodeCachesTableAnnotationComposer,
          $$DbBangumiEpisodeCachesTableCreateCompanionBuilder,
          $$DbBangumiEpisodeCachesTableUpdateCompanionBuilder,
          (
            DbBangumiEpisodeCache,
            BaseReferences<
              _$AppDatabase,
              $DbBangumiEpisodeCachesTable,
              DbBangumiEpisodeCache
            >,
          ),
          DbBangumiEpisodeCache,
          PrefetchHooks Function()
        > {
  $$DbBangumiEpisodeCachesTableTableManager(
    _$AppDatabase db,
    $DbBangumiEpisodeCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbBangumiEpisodeCachesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DbBangumiEpisodeCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DbBangumiEpisodeCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> episodesJson = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
              }) => DbBangumiEpisodeCachesCompanion(
                id: id,
                subjectId: subjectId,
                episodesJson: episodesJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String episodesJson,
                required int cachedAt,
                required int expiresAt,
              }) => DbBangumiEpisodeCachesCompanion.insert(
                id: id,
                subjectId: subjectId,
                episodesJson: episodesJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbBangumiEpisodeCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbBangumiEpisodeCachesTable,
      DbBangumiEpisodeCache,
      $$DbBangumiEpisodeCachesTableFilterComposer,
      $$DbBangumiEpisodeCachesTableOrderingComposer,
      $$DbBangumiEpisodeCachesTableAnnotationComposer,
      $$DbBangumiEpisodeCachesTableCreateCompanionBuilder,
      $$DbBangumiEpisodeCachesTableUpdateCompanionBuilder,
      (
        DbBangumiEpisodeCache,
        BaseReferences<
          _$AppDatabase,
          $DbBangumiEpisodeCachesTable,
          DbBangumiEpisodeCache
        >,
      ),
      DbBangumiEpisodeCache,
      PrefetchHooks Function()
    >;
typedef $$DbBangumiPersonCachesTableCreateCompanionBuilder =
    DbBangumiPersonCachesCompanion Function({
      Value<int> id,
      required int subjectId,
      required String personsJson,
      required int cachedAt,
      required int expiresAt,
    });
typedef $$DbBangumiPersonCachesTableUpdateCompanionBuilder =
    DbBangumiPersonCachesCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> personsJson,
      Value<int> cachedAt,
      Value<int> expiresAt,
    });

class $$DbBangumiPersonCachesTableFilterComposer
    extends Composer<_$AppDatabase, $DbBangumiPersonCachesTable> {
  $$DbBangumiPersonCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personsJson => $composableBuilder(
    column: $table.personsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbBangumiPersonCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbBangumiPersonCachesTable> {
  $$DbBangumiPersonCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personsJson => $composableBuilder(
    column: $table.personsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbBangumiPersonCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbBangumiPersonCachesTable> {
  $$DbBangumiPersonCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get personsJson => $composableBuilder(
    column: $table.personsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$DbBangumiPersonCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbBangumiPersonCachesTable,
          DbBangumiPersonCache,
          $$DbBangumiPersonCachesTableFilterComposer,
          $$DbBangumiPersonCachesTableOrderingComposer,
          $$DbBangumiPersonCachesTableAnnotationComposer,
          $$DbBangumiPersonCachesTableCreateCompanionBuilder,
          $$DbBangumiPersonCachesTableUpdateCompanionBuilder,
          (
            DbBangumiPersonCache,
            BaseReferences<
              _$AppDatabase,
              $DbBangumiPersonCachesTable,
              DbBangumiPersonCache
            >,
          ),
          DbBangumiPersonCache,
          PrefetchHooks Function()
        > {
  $$DbBangumiPersonCachesTableTableManager(
    _$AppDatabase db,
    $DbBangumiPersonCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbBangumiPersonCachesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DbBangumiPersonCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DbBangumiPersonCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> personsJson = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
              }) => DbBangumiPersonCachesCompanion(
                id: id,
                subjectId: subjectId,
                personsJson: personsJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String personsJson,
                required int cachedAt,
                required int expiresAt,
              }) => DbBangumiPersonCachesCompanion.insert(
                id: id,
                subjectId: subjectId,
                personsJson: personsJson,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbBangumiPersonCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbBangumiPersonCachesTable,
      DbBangumiPersonCache,
      $$DbBangumiPersonCachesTableFilterComposer,
      $$DbBangumiPersonCachesTableOrderingComposer,
      $$DbBangumiPersonCachesTableAnnotationComposer,
      $$DbBangumiPersonCachesTableCreateCompanionBuilder,
      $$DbBangumiPersonCachesTableUpdateCompanionBuilder,
      (
        DbBangumiPersonCache,
        BaseReferences<
          _$AppDatabase,
          $DbBangumiPersonCachesTable,
          DbBangumiPersonCache
        >,
      ),
      DbBangumiPersonCache,
      PrefetchHooks Function()
    >;
typedef $$DbDownloadRecordsTableCreateCompanionBuilder =
    DbDownloadRecordsCompanion Function({
      Value<int> id,
      required String infoHash,
      required String magnet,
      Value<String?> name,
      Value<String?> animeName,
      Value<String?> bangumiId,
      Value<int?> episodeNumber,
      required int status,
      Value<String?> filePath,
      required int totalSize,
      required int downloaded,
      required int createdAt,
      required int updatedAt,
    });
typedef $$DbDownloadRecordsTableUpdateCompanionBuilder =
    DbDownloadRecordsCompanion Function({
      Value<int> id,
      Value<String> infoHash,
      Value<String> magnet,
      Value<String?> name,
      Value<String?> animeName,
      Value<String?> bangumiId,
      Value<int?> episodeNumber,
      Value<int> status,
      Value<String?> filePath,
      Value<int> totalSize,
      Value<int> downloaded,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

class $$DbDownloadRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DbDownloadRecordsTable> {
  $$DbDownloadRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get infoHash => $composableBuilder(
    column: $table.infoHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get magnet => $composableBuilder(
    column: $table.magnet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animeName => $composableBuilder(
    column: $table.animeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSize => $composableBuilder(
    column: $table.totalSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloaded => $composableBuilder(
    column: $table.downloaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbDownloadRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DbDownloadRecordsTable> {
  $$DbDownloadRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get infoHash => $composableBuilder(
    column: $table.infoHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get magnet => $composableBuilder(
    column: $table.magnet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animeName => $composableBuilder(
    column: $table.animeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSize => $composableBuilder(
    column: $table.totalSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloaded => $composableBuilder(
    column: $table.downloaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbDownloadRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbDownloadRecordsTable> {
  $$DbDownloadRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get infoHash =>
      $composableBuilder(column: $table.infoHash, builder: (column) => column);

  GeneratedColumn<String> get magnet =>
      $composableBuilder(column: $table.magnet, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get animeName =>
      $composableBuilder(column: $table.animeName, builder: (column) => column);

  GeneratedColumn<String> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get totalSize =>
      $composableBuilder(column: $table.totalSize, builder: (column) => column);

  GeneratedColumn<int> get downloaded => $composableBuilder(
    column: $table.downloaded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DbDownloadRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbDownloadRecordsTable,
          DbDownloadRecord,
          $$DbDownloadRecordsTableFilterComposer,
          $$DbDownloadRecordsTableOrderingComposer,
          $$DbDownloadRecordsTableAnnotationComposer,
          $$DbDownloadRecordsTableCreateCompanionBuilder,
          $$DbDownloadRecordsTableUpdateCompanionBuilder,
          (
            DbDownloadRecord,
            BaseReferences<
              _$AppDatabase,
              $DbDownloadRecordsTable,
              DbDownloadRecord
            >,
          ),
          DbDownloadRecord,
          PrefetchHooks Function()
        > {
  $$DbDownloadRecordsTableTableManager(
    _$AppDatabase db,
    $DbDownloadRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbDownloadRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbDownloadRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbDownloadRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> infoHash = const Value.absent(),
                Value<String> magnet = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> animeName = const Value.absent(),
                Value<String?> bangumiId = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int> totalSize = const Value.absent(),
                Value<int> downloaded = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => DbDownloadRecordsCompanion(
                id: id,
                infoHash: infoHash,
                magnet: magnet,
                name: name,
                animeName: animeName,
                bangumiId: bangumiId,
                episodeNumber: episodeNumber,
                status: status,
                filePath: filePath,
                totalSize: totalSize,
                downloaded: downloaded,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String infoHash,
                required String magnet,
                Value<String?> name = const Value.absent(),
                Value<String?> animeName = const Value.absent(),
                Value<String?> bangumiId = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                required int status,
                Value<String?> filePath = const Value.absent(),
                required int totalSize,
                required int downloaded,
                required int createdAt,
                required int updatedAt,
              }) => DbDownloadRecordsCompanion.insert(
                id: id,
                infoHash: infoHash,
                magnet: magnet,
                name: name,
                animeName: animeName,
                bangumiId: bangumiId,
                episodeNumber: episodeNumber,
                status: status,
                filePath: filePath,
                totalSize: totalSize,
                downloaded: downloaded,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbDownloadRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbDownloadRecordsTable,
      DbDownloadRecord,
      $$DbDownloadRecordsTableFilterComposer,
      $$DbDownloadRecordsTableOrderingComposer,
      $$DbDownloadRecordsTableAnnotationComposer,
      $$DbDownloadRecordsTableCreateCompanionBuilder,
      $$DbDownloadRecordsTableUpdateCompanionBuilder,
      (
        DbDownloadRecord,
        BaseReferences<
          _$AppDatabase,
          $DbDownloadRecordsTable,
          DbDownloadRecord
        >,
      ),
      DbDownloadRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DbLocalFavoritesTableTableManager get dbLocalFavorites =>
      $$DbLocalFavoritesTableTableManager(_db, _db.dbLocalFavorites);
  $$DbBangumiSyncQueueTableTableManager get dbBangumiSyncQueue =>
      $$DbBangumiSyncQueueTableTableManager(_db, _db.dbBangumiSyncQueue);
  $$DbBangumiSubjectCachesTableTableManager get dbBangumiSubjectCaches =>
      $$DbBangumiSubjectCachesTableTableManager(
        _db,
        _db.dbBangumiSubjectCaches,
      );
  $$DbBangumiCharacterCachesTableTableManager get dbBangumiCharacterCaches =>
      $$DbBangumiCharacterCachesTableTableManager(
        _db,
        _db.dbBangumiCharacterCaches,
      );
  $$DbBangumiRelationCachesTableTableManager get dbBangumiRelationCaches =>
      $$DbBangumiRelationCachesTableTableManager(
        _db,
        _db.dbBangumiRelationCaches,
      );
  $$DbTimetableCachesTableTableManager get dbTimetableCaches =>
      $$DbTimetableCachesTableTableManager(_db, _db.dbTimetableCaches);
  $$DbRankingCachesTableTableManager get dbRankingCaches =>
      $$DbRankingCachesTableTableManager(_db, _db.dbRankingCaches);
  $$DbBangumiEpisodeCachesTableTableManager get dbBangumiEpisodeCaches =>
      $$DbBangumiEpisodeCachesTableTableManager(
        _db,
        _db.dbBangumiEpisodeCaches,
      );
  $$DbBangumiPersonCachesTableTableManager get dbBangumiPersonCaches =>
      $$DbBangumiPersonCachesTableTableManager(_db, _db.dbBangumiPersonCaches);
  $$DbDownloadRecordsTableTableManager get dbDownloadRecords =>
      $$DbDownloadRecordsTableTableManager(_db, _db.dbDownloadRecords);
}
