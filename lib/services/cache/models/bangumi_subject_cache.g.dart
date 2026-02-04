// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_subject_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBangumiSubjectCacheCollection on Isar {
  IsarCollection<BangumiSubjectCache> get bangumiSubjectCaches =>
      this.collection();
}

const BangumiSubjectCacheSchema = CollectionSchema(
  name: r'BangumiSubjectCache',
  id: -4021381324224273304,
  properties: {
    r'airDate': PropertySchema(
      id: 0,
      name: r'airDate',
      type: IsarType.string,
    ),
    r'airWeekday': PropertySchema(
      id: 1,
      name: r'airWeekday',
      type: IsarType.string,
    ),
    r'bangumiId': PropertySchema(
      id: 2,
      name: r'bangumiId',
      type: IsarType.long,
    ),
    r'cachedAt': PropertySchema(
      id: 3,
      name: r'cachedAt',
      type: IsarType.long,
    ),
    r'description': PropertySchema(
      id: 4,
      name: r'description',
      type: IsarType.string,
    ),
    r'expiresAt': PropertySchema(
      id: 5,
      name: r'expiresAt',
      type: IsarType.long,
    ),
    r'fullJson': PropertySchema(
      id: 6,
      name: r'fullJson',
      type: IsarType.string,
    ),
    r'imageCommon': PropertySchema(
      id: 7,
      name: r'imageCommon',
      type: IsarType.string,
    ),
    r'imageGrid': PropertySchema(
      id: 8,
      name: r'imageGrid',
      type: IsarType.string,
    ),
    r'imageLarge': PropertySchema(
      id: 9,
      name: r'imageLarge',
      type: IsarType.string,
    ),
    r'imageMedium': PropertySchema(
      id: 10,
      name: r'imageMedium',
      type: IsarType.string,
    ),
    r'imageSmall': PropertySchema(
      id: 11,
      name: r'imageSmall',
      type: IsarType.string,
    ),
    r'isExpired': PropertySchema(
      id: 12,
      name: r'isExpired',
      type: IsarType.bool,
    ),
    r'localImagePath': PropertySchema(
      id: 13,
      name: r'localImagePath',
      type: IsarType.string,
    ),
    r'originalTitle': PropertySchema(
      id: 14,
      name: r'originalTitle',
      type: IsarType.string,
    ),
    r'rank': PropertySchema(
      id: 15,
      name: r'rank',
      type: IsarType.long,
    ),
    r'score': PropertySchema(
      id: 16,
      name: r'score',
      type: IsarType.double,
    ),
    r'tagsJson': PropertySchema(
      id: 17,
      name: r'tagsJson',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 18,
      name: r'title',
      type: IsarType.string,
    ),
    r'titleCn': PropertySchema(
      id: 19,
      name: r'titleCn',
      type: IsarType.string,
    ),
    r'totalEpisodes': PropertySchema(
      id: 20,
      name: r'totalEpisodes',
      type: IsarType.long,
    ),
    r'type': PropertySchema(
      id: 21,
      name: r'type',
      type: IsarType.long,
    )
  },
  estimateSize: _bangumiSubjectCacheEstimateSize,
  serialize: _bangumiSubjectCacheSerialize,
  deserialize: _bangumiSubjectCacheDeserialize,
  deserializeProp: _bangumiSubjectCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'bangumiId': IndexSchema(
      id: -1090507705438731985,
      name: r'bangumiId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'bangumiId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _bangumiSubjectCacheGetId,
  getLinks: _bangumiSubjectCacheGetLinks,
  attach: _bangumiSubjectCacheAttach,
  version: '3.1.0+1',
);

int _bangumiSubjectCacheEstimateSize(
  BangumiSubjectCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.airDate;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.airWeekday;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.fullJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imageCommon;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imageGrid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imageLarge;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imageMedium;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imageSmall;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.localImagePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.originalTitle;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.tagsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  {
    final value = object.titleCn;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _bangumiSubjectCacheSerialize(
  BangumiSubjectCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.airDate);
  writer.writeString(offsets[1], object.airWeekday);
  writer.writeLong(offsets[2], object.bangumiId);
  writer.writeLong(offsets[3], object.cachedAt);
  writer.writeString(offsets[4], object.description);
  writer.writeLong(offsets[5], object.expiresAt);
  writer.writeString(offsets[6], object.fullJson);
  writer.writeString(offsets[7], object.imageCommon);
  writer.writeString(offsets[8], object.imageGrid);
  writer.writeString(offsets[9], object.imageLarge);
  writer.writeString(offsets[10], object.imageMedium);
  writer.writeString(offsets[11], object.imageSmall);
  writer.writeBool(offsets[12], object.isExpired);
  writer.writeString(offsets[13], object.localImagePath);
  writer.writeString(offsets[14], object.originalTitle);
  writer.writeLong(offsets[15], object.rank);
  writer.writeDouble(offsets[16], object.score);
  writer.writeString(offsets[17], object.tagsJson);
  writer.writeString(offsets[18], object.title);
  writer.writeString(offsets[19], object.titleCn);
  writer.writeLong(offsets[20], object.totalEpisodes);
  writer.writeLong(offsets[21], object.type);
}

BangumiSubjectCache _bangumiSubjectCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BangumiSubjectCache();
  object.airDate = reader.readStringOrNull(offsets[0]);
  object.airWeekday = reader.readStringOrNull(offsets[1]);
  object.bangumiId = reader.readLong(offsets[2]);
  object.cachedAt = reader.readLong(offsets[3]);
  object.description = reader.readStringOrNull(offsets[4]);
  object.expiresAt = reader.readLong(offsets[5]);
  object.fullJson = reader.readStringOrNull(offsets[6]);
  object.id = id;
  object.imageCommon = reader.readStringOrNull(offsets[7]);
  object.imageGrid = reader.readStringOrNull(offsets[8]);
  object.imageLarge = reader.readStringOrNull(offsets[9]);
  object.imageMedium = reader.readStringOrNull(offsets[10]);
  object.imageSmall = reader.readStringOrNull(offsets[11]);
  object.localImagePath = reader.readStringOrNull(offsets[13]);
  object.originalTitle = reader.readStringOrNull(offsets[14]);
  object.rank = reader.readLongOrNull(offsets[15]);
  object.score = reader.readDoubleOrNull(offsets[16]);
  object.tagsJson = reader.readStringOrNull(offsets[17]);
  object.title = reader.readString(offsets[18]);
  object.titleCn = reader.readStringOrNull(offsets[19]);
  object.totalEpisodes = reader.readLongOrNull(offsets[20]);
  object.type = reader.readLongOrNull(offsets[21]);
  return object;
}

P _bangumiSubjectCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readLongOrNull(offset)) as P;
    case 16:
      return (reader.readDoubleOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readLongOrNull(offset)) as P;
    case 21:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bangumiSubjectCacheGetId(BangumiSubjectCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bangumiSubjectCacheGetLinks(
    BangumiSubjectCache object) {
  return [];
}

void _bangumiSubjectCacheAttach(
    IsarCollection<dynamic> col, Id id, BangumiSubjectCache object) {
  object.id = id;
}

extension BangumiSubjectCacheByIndex on IsarCollection<BangumiSubjectCache> {
  Future<BangumiSubjectCache?> getByBangumiId(int bangumiId) {
    return getByIndex(r'bangumiId', [bangumiId]);
  }

  BangumiSubjectCache? getByBangumiIdSync(int bangumiId) {
    return getByIndexSync(r'bangumiId', [bangumiId]);
  }

  Future<bool> deleteByBangumiId(int bangumiId) {
    return deleteByIndex(r'bangumiId', [bangumiId]);
  }

  bool deleteByBangumiIdSync(int bangumiId) {
    return deleteByIndexSync(r'bangumiId', [bangumiId]);
  }

  Future<List<BangumiSubjectCache?>> getAllByBangumiId(
      List<int> bangumiIdValues) {
    final values = bangumiIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'bangumiId', values);
  }

  List<BangumiSubjectCache?> getAllByBangumiIdSync(List<int> bangumiIdValues) {
    final values = bangumiIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'bangumiId', values);
  }

  Future<int> deleteAllByBangumiId(List<int> bangumiIdValues) {
    final values = bangumiIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'bangumiId', values);
  }

  int deleteAllByBangumiIdSync(List<int> bangumiIdValues) {
    final values = bangumiIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'bangumiId', values);
  }

  Future<Id> putByBangumiId(BangumiSubjectCache object) {
    return putByIndex(r'bangumiId', object);
  }

  Id putByBangumiIdSync(BangumiSubjectCache object, {bool saveLinks = true}) {
    return putByIndexSync(r'bangumiId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBangumiId(List<BangumiSubjectCache> objects) {
    return putAllByIndex(r'bangumiId', objects);
  }

  List<Id> putAllByBangumiIdSync(List<BangumiSubjectCache> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'bangumiId', objects, saveLinks: saveLinks);
  }
}

extension BangumiSubjectCacheQueryWhereSort
    on QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QWhere> {
  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhere>
      anyBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'bangumiId'),
      );
    });
  }
}

extension BangumiSubjectCacheQueryWhere
    on QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QWhereClause> {
  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      bangumiIdEqualTo(int bangumiId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'bangumiId',
        value: [bangumiId],
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      bangumiIdNotEqualTo(int bangumiId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bangumiId',
              lower: [],
              upper: [bangumiId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bangumiId',
              lower: [bangumiId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bangumiId',
              lower: [bangumiId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bangumiId',
              lower: [],
              upper: [bangumiId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      bangumiIdGreaterThan(
    int bangumiId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bangumiId',
        lower: [bangumiId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      bangumiIdLessThan(
    int bangumiId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bangumiId',
        lower: [],
        upper: [bangumiId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterWhereClause>
      bangumiIdBetween(
    int lowerBangumiId,
    int upperBangumiId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bangumiId',
        lower: [lowerBangumiId],
        includeLower: includeLower,
        upper: [upperBangumiId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BangumiSubjectCacheQueryFilter on QueryBuilder<BangumiSubjectCache,
    BangumiSubjectCache, QFilterCondition> {
  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'airDate',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'airDate',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'airDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'airDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'airDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'airDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'airDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'airDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'airDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'airDate',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'airDate',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airDateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'airDate',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'airWeekday',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'airWeekday',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'airWeekday',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'airWeekday',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'airWeekday',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'airWeekday',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'airWeekday',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'airWeekday',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'airWeekday',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'airWeekday',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'airWeekday',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      airWeekdayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'airWeekday',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      bangumiIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bangumiId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      bangumiIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bangumiId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      bangumiIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bangumiId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      bangumiIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bangumiId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      cachedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      cachedAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      cachedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      cachedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cachedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      expiresAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      expiresAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      expiresAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      expiresAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expiresAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'fullJson',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'fullJson',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fullJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fullJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fullJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fullJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fullJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fullJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fullJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fullJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fullJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      fullJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fullJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageCommon',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageCommon',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageCommon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imageCommon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imageCommon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imageCommon',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imageCommon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imageCommon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageCommon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageCommon',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageCommon',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageCommonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageCommon',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageGrid',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageGrid',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageGrid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imageGrid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imageGrid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imageGrid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imageGrid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imageGrid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageGrid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageGrid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageGrid',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageGridIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageGrid',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageLarge',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageLarge',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageLarge',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imageLarge',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imageLarge',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imageLarge',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imageLarge',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imageLarge',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageLarge',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageLarge',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageLarge',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageLargeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageLarge',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageMedium',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageMedium',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageMedium',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imageMedium',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imageMedium',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imageMedium',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imageMedium',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imageMedium',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageMedium',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageMedium',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageMedium',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageMediumIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageMedium',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageSmall',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageSmall',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageSmall',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imageSmall',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imageSmall',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imageSmall',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imageSmall',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imageSmall',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageSmall',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageSmall',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageSmall',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      imageSmallIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageSmall',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      isExpiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isExpired',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localImagePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localImagePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      localImagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'originalTitle',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'originalTitle',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originalTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originalTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originalTitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originalTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originalTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originalTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originalTitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originalTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      originalTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originalTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      rankIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'rank',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      rankIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'rank',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      rankEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rank',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      rankGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rank',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      rankLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rank',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      rankBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rank',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      scoreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'score',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      scoreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'score',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      scoreEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'score',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      scoreGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'score',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      scoreLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'score',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      scoreBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'score',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tagsJson',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tagsJson',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tagsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tagsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tagsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tagsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tagsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tagsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tagsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tagsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tagsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      tagsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tagsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'titleCn',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'titleCn',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'titleCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'titleCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'titleCn',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'titleCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'titleCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'titleCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'titleCn',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleCn',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      titleCnIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'titleCn',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      totalEpisodesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'totalEpisodes',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      totalEpisodesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'totalEpisodes',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      totalEpisodesEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalEpisodes',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      totalEpisodesGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalEpisodes',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      totalEpisodesLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalEpisodes',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      totalEpisodesBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalEpisodes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      typeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'type',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      typeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'type',
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      typeEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      typeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      typeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterFilterCondition>
      typeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BangumiSubjectCacheQueryObject on QueryBuilder<BangumiSubjectCache,
    BangumiSubjectCache, QFilterCondition> {}

extension BangumiSubjectCacheQueryLinks on QueryBuilder<BangumiSubjectCache,
    BangumiSubjectCache, QFilterCondition> {}

extension BangumiSubjectCacheQuerySortBy
    on QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QSortBy> {
  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByAirDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airDate', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByAirDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airDate', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByAirWeekday() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airWeekday', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByAirWeekdayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airWeekday', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByBangumiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByFullJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullJson', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByFullJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullJson', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageCommon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageCommonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageGrid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageGridDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageLarge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageLargeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageMedium() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageMediumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageSmall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByImageSmallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByOriginalTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalTitle', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByOriginalTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalTitle', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByRank() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rank', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByRankDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rank', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTagsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagsJson', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTagsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagsJson', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTitleCn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleCn', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTitleCnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleCn', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTotalEpisodes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalEpisodes', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTotalEpisodesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalEpisodes', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension BangumiSubjectCacheQuerySortThenBy
    on QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QSortThenBy> {
  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByAirDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airDate', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByAirDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airDate', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByAirWeekday() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airWeekday', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByAirWeekdayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'airWeekday', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByBangumiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByFullJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullJson', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByFullJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fullJson', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageCommon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageCommonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageGrid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageGridDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageLarge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageLargeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageMedium() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageMediumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageSmall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByImageSmallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByOriginalTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalTitle', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByOriginalTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalTitle', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByRank() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rank', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByRankDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rank', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTagsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagsJson', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTagsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagsJson', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTitleCn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleCn', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTitleCnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'titleCn', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTotalEpisodes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalEpisodes', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTotalEpisodesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalEpisodes', Sort.desc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QAfterSortBy>
      thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension BangumiSubjectCacheQueryWhereDistinct
    on QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct> {
  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByAirDate({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'airDate', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByAirWeekday({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'airWeekday', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bangumiId');
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByFullJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fullJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByImageCommon({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageCommon', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByImageGrid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageGrid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByImageLarge({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageLarge', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByImageMedium({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageMedium', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByImageSmall({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageSmall', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isExpired');
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByLocalImagePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localImagePath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByOriginalTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originalTitle',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByRank() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rank');
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'score');
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByTagsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tagsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByTitleCn({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'titleCn', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByTotalEpisodes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalEpisodes');
    });
  }

  QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QDistinct>
      distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }
}

extension BangumiSubjectCacheQueryProperty
    on QueryBuilder<BangumiSubjectCache, BangumiSubjectCache, QQueryProperty> {
  QueryBuilder<BangumiSubjectCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      airDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'airDate');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      airWeekdayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'airWeekday');
    });
  }

  QueryBuilder<BangumiSubjectCache, int, QQueryOperations> bangumiIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bangumiId');
    });
  }

  QueryBuilder<BangumiSubjectCache, int, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<BangumiSubjectCache, int, QQueryOperations> expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      fullJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fullJson');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      imageCommonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageCommon');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      imageGridProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageGrid');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      imageLargeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageLarge');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      imageMediumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageMedium');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      imageSmallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageSmall');
    });
  }

  QueryBuilder<BangumiSubjectCache, bool, QQueryOperations>
      isExpiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isExpired');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      localImagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localImagePath');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      originalTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originalTitle');
    });
  }

  QueryBuilder<BangumiSubjectCache, int?, QQueryOperations> rankProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rank');
    });
  }

  QueryBuilder<BangumiSubjectCache, double?, QQueryOperations> scoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'score');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      tagsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tagsJson');
    });
  }

  QueryBuilder<BangumiSubjectCache, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<BangumiSubjectCache, String?, QQueryOperations>
      titleCnProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'titleCn');
    });
  }

  QueryBuilder<BangumiSubjectCache, int?, QQueryOperations>
      totalEpisodesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalEpisodes');
    });
  }

  QueryBuilder<BangumiSubjectCache, int?, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}
