// Generates synthetic iWallet schema 15 using the official Realm Cocoa 10.40.0
// Objective-C framework (Realm Core 13.13.0). No application/user data is read.
#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

@class TransactionItem;
RLM_COLLECTION_TYPE(TransactionItem)

// The persisted/runtime name is exactly Category, while the C identifier avoids
// the Objective-C runtime's existing Category typedef.
__attribute__((objc_runtime_name("Category")))
@interface FixtureCategory : RLMObject
@property RLMObjectId *id;
@property NSString *name;
@property NSString *icon;
@property NSString *color;
@property NSString *type;
@property RLMArray<TransactionItem *><TransactionItem> *transactions;
@end

@interface TransactionItem : RLMObject
@property RLMObjectId *id;
@property RLMObjectId *categoryId;
@property float amount;
@property NSString *note;
@property NSDate *date;
@property NSString *type;
@property (readonly) RLMLinkingObjects<FixtureCategory *> *category;
@end

@implementation FixtureCategory
+ (NSString *)primaryKey { return @"id"; }
+ (NSArray<NSString *> *)requiredProperties { return @[@"id", @"name", @"icon", @"color", @"type"]; }
@end

@implementation TransactionItem
+ (NSString *)primaryKey { return @"id"; }
+ (NSArray<NSString *> *)requiredProperties { return @[@"id", @"categoryId", @"note", @"date", @"type"]; }
+ (NSDictionary<NSString *, RLMPropertyDescriptor *> *)linkingObjectsProperties {
    return @{@"category": [RLMPropertyDescriptor descriptorWithClass:FixtureCategory.class propertyName:@"transactions"]};
}
@end

static RLMObjectId *objectID(NSString *value) {
    NSError *error = nil;
    RLMObjectId *identifier = [[RLMObjectId alloc] initWithString:value error:&error];
    if (!identifier) { NSLog(@"Invalid fixture ID: %@", error); exit(2); }
    return identifier;
}

static TransactionItem *transaction(NSString *identifier, FixtureCategory *category, float amount, NSString *note, NSTimeInterval timestamp) {
    TransactionItem *item = [TransactionItem new];
    item.id = objectID(identifier);
    item.categoryId = category.id;
    item.amount = amount;
    item.note = note;
    item.date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    item.type = category.type;
    return item;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) { fprintf(stderr, "usage: generate-legacy-realm-fixture OUTPUT.realm\n"); return 2; }
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            fprintf(stderr, "Refusing to overwrite an existing file.\n"); return 2;
        }
        RLMRealmConfiguration *configuration = [RLMRealmConfiguration new];
        configuration.fileURL = [NSURL fileURLWithPath:path];
        configuration.schemaVersion = 15;
        configuration.objectClasses = @[FixtureCategory.class, TransactionItem.class];
        NSError *error = nil;
        RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:&error];
        if (!realm) { NSLog(@"Cannot create fixture: %@", error); return 1; }

        FixtureCategory *food = [FixtureCategory new];
        food.id = objectID(@"64a000000000000000000001");
        food.name = @"Продукты"; food.icon = @"cart.fill"; food.color = @"colorPurple"; food.type = @"Expense";
        FixtureCategory *salary = [FixtureCategory new];
        salary.id = objectID(@"64a000000000000000000003");
        salary.name = @"Salary"; salary.icon = @"banknote.fill"; salary.color = @"colorGreen"; salary.type = @"Income";
        [food.transactions addObject:transaction(@"64a000000000000000000002", food, 12.34f, @"Milk / молоко", 1700000000.125)];
        [food.transactions addObject:transaction(@"64a000000000000000000005", food, 0.01f, @"Smallest cent", 1700000001.5)];
        [food.transactions addObject:transaction(@"64a000000000000000000006", food, 12.345f, @"Explicit rounding case", 1700000002.75)];
        [salary.transactions addObject:transaction(@"64a000000000000000000004", salary, 123.45f, @"Synthetic income", 1700000003.875)];
        [realm beginWriteTransaction];
        [realm addObject:food];
        [realm addObject:salary];
        if (![realm commitWriteTransaction:&error]) { NSLog(@"Cannot save fixture: %@", error); return 1; }
        NSLog(@"Created synthetic schema %@ with %lu categories / %lu transactions", @15,
              (unsigned long)[FixtureCategory allObjectsInRealm:realm].count,
              (unsigned long)[TransactionItem allObjectsInRealm:realm].count);
        NSLog(@"%@", realm.schema);
    }
    return 0;
}
