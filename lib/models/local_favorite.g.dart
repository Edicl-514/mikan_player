// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_favorite.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalFavoriteCollection on Isar {
  IsarCollection<LocalFavorite> get localFavorites => this.collection();
}

const LocalFavoriteSchema = CollectionSchema(
  name: r'LocalFavorite',
  id: 72408866013017603,
  properties: {
    r'bangumiId': PropertySchema(
      id: 0,
      name: r'bangumiId',
      type: IsarType.long,
    ),
    r'coverUrl': PropertySchema(
      id: 1,
      name: r'coverUrl',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'score': PropertySchema(
      id: 3,
      name: r'score',
      type: IsarType.double,
    ),
    r'title': PropertySchema(
      id: 4,
      name: r'title',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 5,
      name: r'type',
      type: IsarType.long,
    )
  },
  estimateSize: _localFavoriteEstimateSize,
  serialize: _localFavoriteSerialize,
  deserialize: _localFavoriteDeserialize,
  deserializeProp: _localFavoriteDeserializeProp,
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
  getId: _localFavoriteGetId,
  getLinks: _localFavoriteGetLinks,
  attach: _localFavoriteAttach,
  version: '3.1.0+1',
);

int _localFavoriteEstimateSize(
  LocalFavorite object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.coverUrl.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _localFavoriteSerialize(
  LocalFavorite object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.bangumiId);
  writer.writeString(offsets[1], object.coverUrl);
  writer.writeLong(offsets[2], object.createdAt);
  writer.writeDouble(offsets[3], object.score);
  writer.writeString(offsets[4], object.title);
  writer.writeLong(offsets[5], object.type);
}

LocalFavorite _localFavoriteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalFavorite();
  object.bangumiId = reader.readLong(offsets[0]);
  object.coverUrl = reader.readString(offsets[1]);
  object.createdAt = reader.readLong(offsets[2]);
  object.id = id;
  object.score = reader.readDouble(offsets[3]);
  object.title = reader.readString(offsets[4]);
  object.type = reader.readLong(offsets[5]);
  return object;
}

P _localFavoriteDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localFavoriteGetId(LocalFavorite object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localFavoriteGetLinks(LocalFavorite object) {
  return [];
}

void _localFavoriteAttach(
    IsarCollection<dynamic> col, Id id, LocalFavorite object) {
  object.id = id;
}

extension LocalFavoriteByIndex on IsarCollection<LocalFavorite> {
  Future<LocalFavorite?> getByBangumiId(int bangumiId) {
    return getByIndex(r'bangumiId', [bangumiId]);
  }

  LocalFavorite? getByBangumiIdSync(int bangumiId) {
    return getByIndexSync(r'bangumiId', [bangumiId]);
  }

  Future<bool> deleteByBangumiId(int bangumiId) {
    return deleteByIndex(r'bangumiId', [bangumiId]);
  }

  bool deleteByBangumiIdSync(int bangumiId) {
    return deleteByIndexSync(r'bangumiId', [bangumiId]);
  }

  Future<List<LocalFavorite?>> getAllByBangumiId(List<int> bangumiIdValues) {
    final values = bangumiIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'bangumiId', values);
  }

  List<LocalFavorite?> getAllByBangumiIdSync(List<int> bangumiIdValues) {
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

  Future<Id> putByBangumiId(LocalFavorite object) {
    return putByIndex(r'bangumiId', object);
  }

  Id putByBangumiIdSync(LocalFavorite object, {bool saveLinks = true}) {
    return putByIndexSync(r'bangumiId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBangumiId(List<LocalFavorite> objects) {
    return putAllByIndex(r'bangumiId', objects);
  }

  List<Id> putAllByBangumiIdSync(List<LocalFavorite> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'bangumiId', objects, saveLinks: saveLinks);
  }
}

extension LocalFavoriteQueryWhereSort
    on QueryBuilder<LocalFavorite, LocalFavorite, QWhere> {
  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhere> anyBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'bangumiId'),
      );
    });
  }
}

extension LocalFavoriteQueryWhere
    on QueryBuilder<LocalFavorite, LocalFavorite, QWhereClause> {
  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause> idBetween(
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause>
      bangumiIdEqualTo(int bangumiId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'bangumiId',
        value: [bangumiId],
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterWhereClause>
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

extension LocalFavoriteQueryFilter
    on QueryBuilder<LocalFavorite, LocalFavorite, QFilterCondition> {
  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      bangumiIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bangumiId',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coverUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'coverUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'coverUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      coverUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'coverUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      createdAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      createdAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition> idBetween(
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      scoreEqualTo(
    double value, {
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      scoreGreaterThan(
    double value, {
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      scoreLessThan(
    double value, {
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      scoreBetween(
    double lower,
    double upper, {
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition> typeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      typeGreaterThan(
    int value, {
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition>
      typeLessThan(
    int value, {
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

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterFilterCondition> typeBetween(
    int lower,
    int upper, {
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

extension LocalFavoriteQueryObject
    on QueryBuilder<LocalFavorite, LocalFavorite, QFilterCondition> {}

extension LocalFavoriteQueryLinks
    on QueryBuilder<LocalFavorite, LocalFavorite, QFilterCondition> {}

extension LocalFavoriteQuerySortBy
    on QueryBuilder<LocalFavorite, LocalFavorite, QSortBy> {
  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy>
      sortByBangumiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByCoverUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy>
      sortByCoverUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension LocalFavoriteQuerySortThenBy
    on QueryBuilder<LocalFavorite, LocalFavorite, QSortThenBy> {
  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy>
      thenByBangumiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByCoverUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy>
      thenByCoverUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'score', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension LocalFavoriteQueryWhereDistinct
    on QueryBuilder<LocalFavorite, LocalFavorite, QDistinct> {
  QueryBuilder<LocalFavorite, LocalFavorite, QDistinct> distinctByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bangumiId');
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QDistinct> distinctByCoverUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coverUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QDistinct> distinctByScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'score');
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFavorite, LocalFavorite, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }
}

extension LocalFavoriteQueryProperty
    on QueryBuilder<LocalFavorite, LocalFavorite, QQueryProperty> {
  QueryBuilder<LocalFavorite, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalFavorite, int, QQueryOperations> bangumiIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bangumiId');
    });
  }

  QueryBuilder<LocalFavorite, String, QQueryOperations> coverUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverUrl');
    });
  }

  QueryBuilder<LocalFavorite, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<LocalFavorite, double, QQueryOperations> scoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'score');
    });
  }

  QueryBuilder<LocalFavorite, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<LocalFavorite, int, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}
