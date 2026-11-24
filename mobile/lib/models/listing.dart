import 'user.dart';

class DateRangeValue {
  const DateRangeValue({required this.startDate, required this.endDate});

  final String startDate;
  final String endDate;

  factory DateRangeValue.fromJson(Map<String, dynamic> json) => DateRangeValue(
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
      );

  Map<String, dynamic> toJson() => {
        'start_date': startDate,
        'end_date': endDate,
      };
}

class BlockRange extends DateRangeValue {
  const BlockRange({
    required this.id,
    required super.startDate,
    required super.endDate,
  });

  final String id;

  factory BlockRange.fromJson(Map<String, dynamic> json) => BlockRange(
        id: json['id'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
      );
}

class CatalogOptions {
  const CatalogOptions({required this.categories, required this.areas});

  final List<String> categories;
  final List<String> areas;

  factory CatalogOptions.fromJson(Map<String, dynamic> json) => CatalogOptions(
        categories: List<String>.from(json['categories'] as List<dynamic>),
        areas: List<String>.from(json['areas'] as List<dynamic>),
      );
}

class ListingInput {
  const ListingInput({
    required this.title,
    required this.category,
    required this.description,
    required this.condition,
    required this.accessories,
    required this.photoIds,
    required this.dailyRate,
    required this.deposit,
    required this.area,
    required this.pickupPoint,
  });

  final String title;
  final String category;
  final String description;
  final String condition;
  final List<String> accessories;
  final List<String> photoIds;
  final int dailyRate;
  final int deposit;
  final String area;
  final String pickupPoint;

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'description': description,
        'condition': condition,
        'accessories': accessories,
        'photo_ids': photoIds,
        'daily_rate': dailyRate,
        'deposit': deposit,
        'area': area,
        'pickup_point': pickupPoint,
      };
}

class Listing extends ListingInput {
  const Listing({
    required this.id,
    required this.owner,
    required this.revision,
    required super.title,
    required super.category,
    required super.description,
    required super.condition,
    required super.accessories,
    required super.photoIds,
    required super.dailyRate,
    required super.deposit,
    required super.area,
    required super.pickupPoint,
  });

  final String id;
  final UserSummary owner;
  final int revision;

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id'] as String,
        owner: UserSummary.fromJson(json['owner'] as Map<String, dynamic>),
        revision: (json['revision'] as num).toInt(),
        title: json['title'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        condition: json['condition'] as String,
        accessories: List<String>.from(json['accessories'] as List<dynamic>),
        photoIds: List<String>.from(json['photo_ids'] as List<dynamic>),
        dailyRate: (json['daily_rate'] as num).toInt(),
        deposit: (json['deposit'] as num).toInt(),
        area: json['area'] as String,
        pickupPoint: json['pickup_point'] as String,
      );
}

class Quote {
  const Quote({
    required this.listingId,
    required this.listingRevision,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.dailyRate,
    required this.rent,
    required this.deposit,
    required this.renterFee,
    required this.ownerFee,
    required this.pickupTotal,
    required this.ownerNet,
  });

  final String listingId;
  final int listingRevision;
  final String startDate;
  final String endDate;
  final int days;
  final int dailyRate;
  final int rent;
  final int deposit;
  final int renterFee;
  final int ownerFee;
  final int pickupTotal;
  final int ownerNet;

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        listingId: json['listing_id'] as String,
        listingRevision: (json['listing_revision'] as num).toInt(),
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
        days: (json['days'] as num).toInt(),
        dailyRate: (json['daily_rate'] as num).toInt(),
        rent: (json['rent'] as num).toInt(),
        deposit: (json['deposit'] as num).toInt(),
        renterFee: (json['renter_fee'] as num).toInt(),
        ownerFee: (json['owner_fee'] as num).toInt(),
        pickupTotal: (json['pickup_total'] as num).toInt(),
        ownerNet: (json['owner_net'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'listing_revision': listingRevision,
        'start_date': startDate,
        'end_date': endDate,
        'days': days,
        'daily_rate': dailyRate,
        'rent': rent,
        'deposit': deposit,
        'renter_fee': renterFee,
        'owner_fee': ownerFee,
        'pickup_total': pickupTotal,
        'owner_net': ownerNet,
      };
}
