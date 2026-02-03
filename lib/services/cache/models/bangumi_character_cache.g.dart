// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_character_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBangumiCharacterCacheCollection on Isar {
  IsarCollection<BangumiCharacterCache> get bangumiCharacterCaches =>
      this.collection();
}

const BangumiCharacterCacheSchema = CollectionSchema(
  name: r'BangumiCharacterCache',
  id: -555811077709090038,
  properties: {
    r'actorsJson': PropertySchema(
      id: 0,
      name: r'actorsJson',
      type: IsarType.string,
    ),
    r'cachedAt': PropertySchema(
      id: 1,
      name: r'cachedAt',
      type: IsarType.long,
    ),
    r'characterId': PropertySchema(
      id: 2,
      name: r'characterId',
      type: IsarType.long,
    ),
    r'expiresAt': PropertySchema(
      id: 3,
      name: r'expiresAt',
      type: IsarType.long,
    ),
    r'imageCommon': PropertySchema(
      id: 4,
      name: r'imageCommon',
      type: IsarType.string,
    ),
    r'imageGrid': PropertySchema(
      id: 5,
      name: r'imageGrid',
      type: IsarType.string,
    ),
    r'imageLarge': PropertySchema(
      id: 6,
      name: r'imageLarge',
      type: IsarType.string,
    ),
    r'imageMedium': PropertySchema(
      id: 7,
      name: r'imageMedium',
      type: IsarType.string,
    ),
    r'imageSmall': PropertySchema(
      id: 8,
      name: r'imageSmall',
      type: IsarType.string,
    ),
    r'isExpired': PropertySchema(
      id: 9,
      name: r'isExpired',
      type: IsarType.bool,
    ),
    r'localImagePath': PropertySchema(
      id: 10,
      name: r'localImagePath',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 11,
      name: r'name',
      type: IsarType.string,
    ),
    r'roleName': PropertySchema(
      id: 12,
      name: r'roleName',
      type: IsarType.string,
    ),
    r'subjectId': PropertySchema(
      id: 13,
      name: r'subjectId',
      type: IsarType.long,
    )
  },
  estimateSize: _bangumiCharacterCacheEstimateSize,
  serialize: _bangumiCharacterCacheSerialize,
  deserialize: _bangumiCharacterCacheDeserialize,
  deserializeProp: _bangumiCharacterCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'subjectId': IndexSchema(
      id: 440306668014799972,
      name: r'subjectId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'subjectId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _bangumiCharacterCacheGetId,
  getLinks: _bangumiCharacterCacheGetLinks,
  attach: _bangumiCharacterCacheAttach,
  version: '3.1.0+1',
);

int _bangumiCharacterCacheEstimateSize(
  BangumiCharacterCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.actorsJson;
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
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.roleName.length * 3;
  return bytesCount;
}

void _bangumiCharacterCacheSerialize(
  BangumiCharacterCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.actorsJson);
  writer.writeLong(offsets[1], object.cachedAt);
  writer.writeLong(offsets[2], object.characterId);
  writer.writeLong(offsets[3], object.expiresAt);
  writer.writeString(offsets[4], object.imageCommon);
  writer.writeString(offsets[5], object.imageGrid);
  writer.writeString(offsets[6], object.imageLarge);
  writer.writeString(offsets[7], object.imageMedium);
  writer.writeString(offsets[8], object.imageSmall);
  writer.writeBool(offsets[9], object.isExpired);
  writer.writeString(offsets[10], object.localImagePath);
  writer.writeString(offsets[11], object.name);
  writer.writeString(offsets[12], object.roleName);
  writer.writeLong(offsets[13], object.subjectId);
}

BangumiCharacterCache _bangumiCharacterCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BangumiCharacterCache();
  object.actorsJson = reader.readStringOrNull(offsets[0]);
  object.cachedAt = reader.readLong(offsets[1]);
  object.characterId = reader.readLong(offsets[2]);
  object.expiresAt = reader.readLong(offsets[3]);
  object.id = id;
  object.imageCommon = reader.readStringOrNull(offsets[4]);
  object.imageGrid = reader.readStringOrNull(offsets[5]);
  object.imageLarge = reader.readStringOrNull(offsets[6]);
  object.imageMedium = reader.readStringOrNull(offsets[7]);
  object.imageSmall = reader.readStringOrNull(offsets[8]);
  object.localImagePath = reader.readStringOrNull(offsets[10]);
  object.name = reader.readString(offsets[11]);
  object.roleName = reader.readString(offsets[12]);
  object.subjectId = reader.readLong(offsets[13]);
  return object;
}

P _bangumiCharacterCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bangumiCharacterCacheGetId(BangumiCharacterCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bangumiCharacterCacheGetLinks(
    BangumiCharacterCache object) {
  return [];
}

void _bangumiCharacterCacheAttach(
    IsarCollection<dynamic> col, Id id, BangumiCharacterCache object) {
  object.id = id;
}

extension BangumiCharacterCacheQueryWhereSort
    on QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QWhere> {
  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhere>
      anySubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'subjectId'),
      );
    });
  }
}

extension BangumiCharacterCacheQueryWhere on QueryBuilder<BangumiCharacterCache,
    BangumiCharacterCache, QWhereClause> {
  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      subjectIdEqualTo(int subjectId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'subjectId',
        value: [subjectId],
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      subjectIdNotEqualTo(int subjectId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'subjectId',
              lower: [],
              upper: [subjectId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'subjectId',
              lower: [subjectId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'subjectId',
              lower: [subjectId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'subjectId',
              lower: [],
              upper: [subjectId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      subjectIdGreaterThan(
    int subjectId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'subjectId',
        lower: [subjectId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      subjectIdLessThan(
    int subjectId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'subjectId',
        lower: [],
        upper: [subjectId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterWhereClause>
      subjectIdBetween(
    int lowerSubjectId,
    int upperSubjectId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'subjectId',
        lower: [lowerSubjectId],
        includeLower: includeLower,
        upper: [upperSubjectId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BangumiCharacterCacheQueryFilter on QueryBuilder<
    BangumiCharacterCache, BangumiCharacterCache, QFilterCondition> {
  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'actorsJson',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'actorsJson',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actorsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      actorsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actorsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      actorsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actorsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actorsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> actorsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actorsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> cachedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> cachedAtGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> cachedAtLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> cachedAtBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> characterIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characterId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> characterIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'characterId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> characterIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'characterId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> characterIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'characterId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> expiresAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> expiresAtGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> expiresAtLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> expiresAtBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> idLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> idBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageCommon',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageCommon',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonEqualTo(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonStartsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonEndsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageCommonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageCommon',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageCommonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageCommon',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageCommon',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageCommonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageCommon',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageGrid',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageGrid',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridEqualTo(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridStartsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridEndsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageGridContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageGrid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageGridMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageGrid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageGrid',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageGridIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageGrid',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageLarge',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageLarge',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeEqualTo(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeStartsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeEndsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageLargeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageLarge',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageLargeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageLarge',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageLarge',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageLargeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageLarge',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageMedium',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageMedium',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumEqualTo(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumStartsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumEndsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageMediumContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageMedium',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageMediumMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageMedium',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageMedium',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageMediumIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageMedium',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageSmall',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageSmall',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallEqualTo(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallStartsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallEndsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageSmallContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageSmall',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      imageSmallMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageSmall',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageSmall',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> imageSmallIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageSmall',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> isExpiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isExpired',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathEqualTo(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathGreaterThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathLessThan(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathBetween(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathStartsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathEndsWith(
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

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      localImagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localImagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      localImagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localImagePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> localImagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'roleName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'roleName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'roleName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'roleName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'roleName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'roleName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      roleNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'roleName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
          QAfterFilterCondition>
      roleNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'roleName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'roleName',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> roleNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'roleName',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> subjectIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> subjectIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'subjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> subjectIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'subjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache,
      QAfterFilterCondition> subjectIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'subjectId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BangumiCharacterCacheQueryObject on QueryBuilder<
    BangumiCharacterCache, BangumiCharacterCache, QFilterCondition> {}

extension BangumiCharacterCacheQueryLinks on QueryBuilder<BangumiCharacterCache,
    BangumiCharacterCache, QFilterCondition> {}

extension BangumiCharacterCacheQuerySortBy
    on QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QSortBy> {
  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByActorsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorsJson', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByActorsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorsJson', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByCharacterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByCharacterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageCommon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageCommonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageGrid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageGridDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageLarge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageLargeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageMedium() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageMediumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageSmall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByImageSmallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByRoleName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roleName', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortByRoleNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roleName', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortBySubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subjectId', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      sortBySubjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subjectId', Sort.desc);
    });
  }
}

extension BangumiCharacterCacheQuerySortThenBy
    on QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QSortThenBy> {
  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByActorsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorsJson', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByActorsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actorsJson', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByCharacterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByCharacterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characterId', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageCommon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageCommonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageCommon', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageGrid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageGridDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageGrid', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageLarge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageLargeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageLarge', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageMedium() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageMediumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageMedium', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageSmall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByImageSmallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageSmall', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByRoleName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roleName', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenByRoleNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'roleName', Sort.desc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenBySubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subjectId', Sort.asc);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QAfterSortBy>
      thenBySubjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subjectId', Sort.desc);
    });
  }
}

extension BangumiCharacterCacheQueryWhereDistinct
    on QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct> {
  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByActorsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actorsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByCharacterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characterId');
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByImageCommon({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageCommon', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByImageGrid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageGrid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByImageLarge({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageLarge', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByImageMedium({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageMedium', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByImageSmall({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageSmall', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isExpired');
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByLocalImagePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localImagePath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctByRoleName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'roleName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiCharacterCache, BangumiCharacterCache, QDistinct>
      distinctBySubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subjectId');
    });
  }
}

extension BangumiCharacterCacheQueryProperty on QueryBuilder<
    BangumiCharacterCache, BangumiCharacterCache, QQueryProperty> {
  QueryBuilder<BangumiCharacterCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BangumiCharacterCache, String?, QQueryOperations>
      actorsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actorsJson');
    });
  }

  QueryBuilder<BangumiCharacterCache, int, QQueryOperations>
      cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<BangumiCharacterCache, int, QQueryOperations>
      characterIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characterId');
    });
  }

  QueryBuilder<BangumiCharacterCache, int, QQueryOperations>
      expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<BangumiCharacterCache, String?, QQueryOperations>
      imageCommonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageCommon');
    });
  }

  QueryBuilder<BangumiCharacterCache, String?, QQueryOperations>
      imageGridProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageGrid');
    });
  }

  QueryBuilder<BangumiCharacterCache, String?, QQueryOperations>
      imageLargeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageLarge');
    });
  }

  QueryBuilder<BangumiCharacterCache, String?, QQueryOperations>
      imageMediumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageMedium');
    });
  }

  QueryBuilder<BangumiCharacterCache, String?, QQueryOperations>
      imageSmallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageSmall');
    });
  }

  QueryBuilder<BangumiCharacterCache, bool, QQueryOperations>
      isExpiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isExpired');
    });
  }

  QueryBuilder<BangumiCharacterCache, String?, QQueryOperations>
      localImagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localImagePath');
    });
  }

  QueryBuilder<BangumiCharacterCache, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<BangumiCharacterCache, String, QQueryOperations>
      roleNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'roleName');
    });
  }

  QueryBuilder<BangumiCharacterCache, int, QQueryOperations>
      subjectIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subjectId');
    });
  }
}
