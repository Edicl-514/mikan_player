// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_relation_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBangumiRelationCacheCollection on Isar {
  IsarCollection<BangumiRelationCache> get bangumiRelationCaches =>
      this.collection();
}

const BangumiRelationCacheSchema = CollectionSchema(
  name: r'BangumiRelationCache',
  id: 250057469446682050,
  properties: {
    r'cachedAt': PropertySchema(
      id: 0,
      name: r'cachedAt',
      type: IsarType.long,
    ),
    r'expiresAt': PropertySchema(
      id: 1,
      name: r'expiresAt',
      type: IsarType.long,
    ),
    r'imageUrl': PropertySchema(
      id: 2,
      name: r'imageUrl',
      type: IsarType.string,
    ),
    r'isExpired': PropertySchema(
      id: 3,
      name: r'isExpired',
      type: IsarType.bool,
    ),
    r'localImagePath': PropertySchema(
      id: 4,
      name: r'localImagePath',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 5,
      name: r'name',
      type: IsarType.string,
    ),
    r'nameCn': PropertySchema(
      id: 6,
      name: r'nameCn',
      type: IsarType.string,
    ),
    r'relatedSubjectId': PropertySchema(
      id: 7,
      name: r'relatedSubjectId',
      type: IsarType.long,
    ),
    r'relation': PropertySchema(
      id: 8,
      name: r'relation',
      type: IsarType.string,
    ),
    r'sourceSubjectId': PropertySchema(
      id: 9,
      name: r'sourceSubjectId',
      type: IsarType.long,
    )
  },
  estimateSize: _bangumiRelationCacheEstimateSize,
  serialize: _bangumiRelationCacheSerialize,
  deserialize: _bangumiRelationCacheDeserialize,
  deserializeProp: _bangumiRelationCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'sourceSubjectId': IndexSchema(
      id: 8702529972518161231,
      name: r'sourceSubjectId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sourceSubjectId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _bangumiRelationCacheGetId,
  getLinks: _bangumiRelationCacheGetLinks,
  attach: _bangumiRelationCacheAttach,
  version: '3.1.0+1',
);

int _bangumiRelationCacheEstimateSize(
  BangumiRelationCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.imageUrl;
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
  {
    final value = object.nameCn;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.relation.length * 3;
  return bytesCount;
}

void _bangumiRelationCacheSerialize(
  BangumiRelationCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.cachedAt);
  writer.writeLong(offsets[1], object.expiresAt);
  writer.writeString(offsets[2], object.imageUrl);
  writer.writeBool(offsets[3], object.isExpired);
  writer.writeString(offsets[4], object.localImagePath);
  writer.writeString(offsets[5], object.name);
  writer.writeString(offsets[6], object.nameCn);
  writer.writeLong(offsets[7], object.relatedSubjectId);
  writer.writeString(offsets[8], object.relation);
  writer.writeLong(offsets[9], object.sourceSubjectId);
}

BangumiRelationCache _bangumiRelationCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BangumiRelationCache();
  object.cachedAt = reader.readLong(offsets[0]);
  object.expiresAt = reader.readLong(offsets[1]);
  object.id = id;
  object.imageUrl = reader.readStringOrNull(offsets[2]);
  object.localImagePath = reader.readStringOrNull(offsets[4]);
  object.name = reader.readString(offsets[5]);
  object.nameCn = reader.readStringOrNull(offsets[6]);
  object.relatedSubjectId = reader.readLong(offsets[7]);
  object.relation = reader.readString(offsets[8]);
  object.sourceSubjectId = reader.readLong(offsets[9]);
  return object;
}

P _bangumiRelationCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bangumiRelationCacheGetId(BangumiRelationCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bangumiRelationCacheGetLinks(
    BangumiRelationCache object) {
  return [];
}

void _bangumiRelationCacheAttach(
    IsarCollection<dynamic> col, Id id, BangumiRelationCache object) {
  object.id = id;
}

extension BangumiRelationCacheQueryWhereSort
    on QueryBuilder<BangumiRelationCache, BangumiRelationCache, QWhere> {
  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhere>
      anySourceSubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sourceSubjectId'),
      );
    });
  }
}

extension BangumiRelationCacheQueryWhere
    on QueryBuilder<BangumiRelationCache, BangumiRelationCache, QWhereClause> {
  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      sourceSubjectIdEqualTo(int sourceSubjectId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sourceSubjectId',
        value: [sourceSubjectId],
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      sourceSubjectIdNotEqualTo(int sourceSubjectId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceSubjectId',
              lower: [],
              upper: [sourceSubjectId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceSubjectId',
              lower: [sourceSubjectId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceSubjectId',
              lower: [sourceSubjectId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceSubjectId',
              lower: [],
              upper: [sourceSubjectId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      sourceSubjectIdGreaterThan(
    int sourceSubjectId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceSubjectId',
        lower: [sourceSubjectId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      sourceSubjectIdLessThan(
    int sourceSubjectId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceSubjectId',
        lower: [],
        upper: [sourceSubjectId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterWhereClause>
      sourceSubjectIdBetween(
    int lowerSourceSubjectId,
    int upperSourceSubjectId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceSubjectId',
        lower: [lowerSourceSubjectId],
        includeLower: includeLower,
        upper: [upperSourceSubjectId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BangumiRelationCacheQueryFilter on QueryBuilder<BangumiRelationCache,
    BangumiRelationCache, QFilterCondition> {
  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> cachedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> expiresAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imageUrl',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imageUrl',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imageUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
          QAfterFilterCondition>
      imageUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imageUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
          QAfterFilterCondition>
      imageUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imageUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imageUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> imageUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imageUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> isExpiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isExpired',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> localImagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> localImagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'localImagePath',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> localImagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> localImagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localImagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
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

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'nameCn',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'nameCn',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nameCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nameCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nameCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nameCn',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'nameCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'nameCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
          QAfterFilterCondition>
      nameCnContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'nameCn',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
          QAfterFilterCondition>
      nameCnMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'nameCn',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nameCn',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> nameCnIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'nameCn',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relatedSubjectIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relatedSubjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relatedSubjectIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'relatedSubjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relatedSubjectIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'relatedSubjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relatedSubjectIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'relatedSubjectId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'relation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
          QAfterFilterCondition>
      relationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'relation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
          QAfterFilterCondition>
      relationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'relation',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'relation',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> relationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'relation',
        value: '',
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> sourceSubjectIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceSubjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> sourceSubjectIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceSubjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> sourceSubjectIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceSubjectId',
        value: value,
      ));
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache,
      QAfterFilterCondition> sourceSubjectIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceSubjectId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BangumiRelationCacheQueryObject on QueryBuilder<BangumiRelationCache,
    BangumiRelationCache, QFilterCondition> {}

extension BangumiRelationCacheQueryLinks on QueryBuilder<BangumiRelationCache,
    BangumiRelationCache, QFilterCondition> {}

extension BangumiRelationCacheQuerySortBy
    on QueryBuilder<BangumiRelationCache, BangumiRelationCache, QSortBy> {
  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByImageUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByImageUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByNameCn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameCn', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByNameCnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameCn', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByRelatedSubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relatedSubjectId', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByRelatedSubjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relatedSubjectId', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByRelation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortByRelationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortBySourceSubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSubjectId', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      sortBySourceSubjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSubjectId', Sort.desc);
    });
  }
}

extension BangumiRelationCacheQuerySortThenBy
    on QueryBuilder<BangumiRelationCache, BangumiRelationCache, QSortThenBy> {
  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByImageUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByImageUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByLocalImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByLocalImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localImagePath', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByNameCn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameCn', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByNameCnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameCn', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByRelatedSubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relatedSubjectId', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByRelatedSubjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relatedSubjectId', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByRelation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenByRelationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'relation', Sort.desc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenBySourceSubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSubjectId', Sort.asc);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QAfterSortBy>
      thenBySourceSubjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSubjectId', Sort.desc);
    });
  }
}

extension BangumiRelationCacheQueryWhereDistinct
    on QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct> {
  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByImageUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isExpired');
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByLocalImagePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localImagePath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByNameCn({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nameCn', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByRelatedSubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'relatedSubjectId');
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctByRelation({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'relation', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BangumiRelationCache, BangumiRelationCache, QDistinct>
      distinctBySourceSubjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceSubjectId');
    });
  }
}

extension BangumiRelationCacheQueryProperty on QueryBuilder<
    BangumiRelationCache, BangumiRelationCache, QQueryProperty> {
  QueryBuilder<BangumiRelationCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BangumiRelationCache, int, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<BangumiRelationCache, int, QQueryOperations>
      expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<BangumiRelationCache, String?, QQueryOperations>
      imageUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageUrl');
    });
  }

  QueryBuilder<BangumiRelationCache, bool, QQueryOperations>
      isExpiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isExpired');
    });
  }

  QueryBuilder<BangumiRelationCache, String?, QQueryOperations>
      localImagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localImagePath');
    });
  }

  QueryBuilder<BangumiRelationCache, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<BangumiRelationCache, String?, QQueryOperations>
      nameCnProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nameCn');
    });
  }

  QueryBuilder<BangumiRelationCache, int, QQueryOperations>
      relatedSubjectIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'relatedSubjectId');
    });
  }

  QueryBuilder<BangumiRelationCache, String, QQueryOperations>
      relationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'relation');
    });
  }

  QueryBuilder<BangumiRelationCache, int, QQueryOperations>
      sourceSubjectIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceSubjectId');
    });
  }
}
