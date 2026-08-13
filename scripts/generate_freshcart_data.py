"""
FreshCart synthetic data generator.
Produces 8 CSVs matching stage_sch table column order exactly (text-friendly,
ready for Snowsight's Load Data wizard with SKIP_HEADER=1).
"""
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path
from faker import Faker

fake = Faker("de_DE")
random.seed(42)
Faker.seed(42)

OUT = Path("/mnt/user-data/outputs/freshcart_synthetic_data")
OUT.mkdir(parents=True, exist_ok=True)

CITIES = [
    ("Munich", "Bavaria"), ("Berlin", "Berlin"), ("Hamburg", "Hamburg"),
    ("Cologne", "North Rhine-Westphalia"), ("Frankfurt", "Hesse"),
    ("Stuttgart", "Baden-Württemberg"), ("Düsseldorf", "North Rhine-Westphalia"),
    ("Leipzig", "Saxony"),
]

def dt(days_back_max=400):
    return (datetime.now() - timedelta(days=random.randint(0, days_back_max))).strftime("%Y-%m-%d %H:%M:%S")

def write_csv(filename, header, rows):
    path = OUT / filename
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{filename}: {len(rows)} rows")

# ---- 1. LOCATION ----
locations = []
for i in range(1, 11):
    city, state = CITIES[(i - 1) % len(CITIES)]
    locations.append([i, city, state, fake.postcode(), "Y", dt(), dt()])
write_csv("location.csv",
    ["location_id","city","state","zipcode","active_flag","created_date","modified_date"],
    locations)

# ---- 2. CUSTOMER ----
customers = []
for i in range(1, 121):
    name = fake.name()
    customers.append([i, name, fake.phone_number(), fake.email(),
                       random.choice(["Male","Female","Other"]),
                       fake.date_of_birth(minimum_age=18, maximum_age=70).strftime("%Y-%m-%d"),
                       dt(), dt()])
write_csv("customer.csv",
    ["customer_id","name","mobile","email","gender","dob","created_date","modified_date"],
    customers)

# ---- 3. RESTAURANT ----
cuisines = ["German","Italian","Turkish","Indian","Vietnamese","Vegan","Bakery","Burger"]
restaurants = []
for i in range(1, 26):
    loc_id = random.randint(1, 10)
    restaurants.append([i, f"{fake.last_name()}'s {random.choice(cuisines)} Kitchen",
                         random.choice(cuisines), round(random.uniform(15, 60), 2),
                         fake.phone_number(), "10:00-22:00", loc_id,
                         "Y", random.choice(["Open","Closed"]), dt(), dt()])
write_csv("restaurant.csv",
    ["restaurant_id","name","cuisine_type","pricing_for_two","restaurant_phone",
     "operating_hours","location_id","active_flag","open_status","created_date","modified_date"],
    restaurants)

# ---- 4. MENU ----
items = ["Schnitzel","Pizza Margherita","Doner Kebab","Butter Chicken","Pho Bo",
         "Vegan Buddha Bowl","Pretzel","Cheeseburger","Currywurst","Falafel Wrap"]
menu = []
menu_id = 1
for r in restaurants:
    for _ in range(random.randint(4, 8)):
        menu.append([menu_id, r[0], random.choice(items), fake.sentence(nb_words=6),
                      round(random.uniform(4, 22), 2), r[2],
                      random.choice(["true","false"]),
                      random.choice(["Veg","Non-Veg","Vegan"]), dt(), dt()])
        menu_id += 1
write_csv("menu.csv",
    ["menu_id","restaurant_id","item_name","description","price","category",
     "availability","item_type","created_date","modified_date"],
    menu)

# ---- 5. DELIVERY_AGENT ----
agents = []
for i in range(1, 31):
    agents.append([i, fake.name(), fake.phone_number(),
                    random.choice(["Bike","Scooter","Bicycle","Car"]),
                    random.randint(1, 10), random.choice(["Active","Inactive"]),
                    random.choice(["Male","Female"]), round(random.uniform(3.0, 5.0), 2),
                    dt(), dt()])
write_csv("delivery_agent.csv",
    ["delivery_agent_id","name","phone","vehicle_type","location_id","status",
     "gender","rating","created_date","modified_date"],
    agents)

# ---- 6. CUSTOMER_ADDRESS ----
addresses = []
addr_id = 1
for c in customers:
    for _ in range(random.randint(1, 2)):
        city, state = random.choice(CITIES)
        addresses.append([addr_id, c[0], str(random.randint(1,20)), str(random.randint(1,150)),
                           str(random.randint(0,10)), fake.company(), fake.street_name(),
                           fake.city_suffix(), city, state, fake.postcode(),
                           f"{fake.latitude()},{fake.longitude()}",
                           "Y" if _ == 0 else "N", random.choice(["Home","Work"]),
                           dt(), dt()])
        addr_id += 1
write_csv("customer_address.csv",
    ["address_id","customer_id","flat_no","house_no","floor","building","landmark",
     "locality","city","state","pincode","coordinates","primary_flag","address_type",
     "created_date","modified_date"],
    addresses)

# ---- 7. ORDERS ----
orders = []
for i in range(1, 301):
    cust = random.choice(customers)
    rest = random.choice(restaurants)
    orders.append([i, cust[0], rest[0], dt(200),
                    round(random.uniform(10, 120), 2),
                    random.choice(["Delivered","Cancelled","Placed","In Progress"]),
                    random.choice(["Card","Cash","UPI","Wallet"]), dt(), dt()])
write_csv("orders.csv",
    ["order_id","customer_id","restaurant_id","order_date","total_amount","status",
     "payment_method","created_date","modified_date"],
    orders)

# ---- 8. ORDER_ITEM ----
order_items = []
oi_id = 1
menu_by_restaurant = {}
for m in menu:
    menu_by_restaurant.setdefault(m[1], []).append(m)

for o in orders:
    rest_menu = menu_by_restaurant.get(o[2], [])
    if not rest_menu:
        continue
    for _ in range(random.randint(1, 4)):
        item = random.choice(rest_menu)
        qty = random.randint(1, 3)
        price = item[4]
        order_items.append([oi_id, o[0], item[0], qty, price, round(qty * price, 2), dt(), dt()])
        oi_id += 1
write_csv("order_item.csv",
    ["order_item_id","order_id","menu_id","quantity","price","subtotal",
     "created_date","modified_date"],
    order_items)

# ---- 9. DELIVERY (added in Phase 4 — links each order to the agent who delivered it) ----
delivery = []
delivery_statuses = ["Delivered","Delivered","Delivered","Cancelled","In Transit"]  # weighted toward Delivered
for o in orders:
    agent = random.choice(agents)
    delivery.append([o[0], o[0], agent[0],
                      random.choice(delivery_statuses),
                      f"{random.randint(15,60)} mins",
                      dt(200), dt()])
write_csv("delivery.csv",
    ["delivery_id","order_id","delivery_agent_id","delivery_status","estimated_time",
     "created_date","modified_date"],
    delivery)

print(f"\nAll files written to {OUT}")