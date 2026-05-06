import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showMenu = false;
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEAF0),

      body: Center(
        child: Container(
          width: 375,
          color: Colors.white,
          child: SafeArea(
            child: Stack(
              children: [

                // MAIN CONTENT
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hello, User!",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text("What are we planning today?",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                AssetImage("images/avatar.png"),
                          )
                        ],
                      ),

                      const SizedBox(height: 20),

                      // SPIN CARD
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Can’t decide where to go?"),
                                const Text("Spin the Wheel!",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),

                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFF5B335),
                                  ),
                                  onPressed: () {},
                                  child: const Text("Try it now",
                                      style:
                                          TextStyle(color: Colors.black)),
                                )
                              ],
                            ),

                            Image.asset(
                              "images/wheel.png",
                              height: 70,
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // UPCOMING
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Upcoming Plans",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text("View all",
                              style: TextStyle(color: Colors.grey))
                        ],
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: ListView(
                          children: [
                            buildPlan(
                                "Dinner sa Japan lang",
                                "Apr 8 • Ramen House, Tokyo, Japan",
                                "Planned",
                                5),
                            buildPlan(
                                "Picnic with Family",
                                "Apr 15 • Kahit saang tabing ilog",
                                "Planned",
                                3),
                            buildPlan(
                                "Birthday ni Kenny",
                                "Apr 29 • Boracay, Philippines",
                                "Ongoing",
                                3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // FLOAT MENU
                Positioned(
                  bottom: 110,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [

                      if (showMenu)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6)
                            ],
                          ),
                          child: Column(
                            children: [
                              menuItem("Create Plan"),
                              menuItem("Join Plan"),
                              menuItem("Quick Decision"),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      FloatingActionButton(
                        backgroundColor:
                            const Color(0xFFF5B335),
                        onPressed: () {
                          setState(() {
                            showMenu = !showMenu;
                          });
                        },
                        child: const Icon(Icons.add,
                            color: Colors.black),
                      ),
                    ],
                  ),
                ),

                // BOTTOM NAV
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                      children: [
                        navItem(Icons.home, "Home", 0),
                        navItem(Icons.add_circle_outline, "My Plans", 1),
                        navItem(Icons.notifications_none, "Activity", 2),
                        navItem(Icons.settings, "Settings", 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int index) {
    bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = index);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: isActive ? Colors.orange : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.orange : Colors.grey,
              ))
        ],
      ),
    );
  }

  Widget buildPlan(
      String title, String subtitle, String status, int users) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 5),

          Text(subtitle,
              style: const TextStyle(color: Colors.grey)),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [

              Row(
                children: List.generate(
                  users,
                  (index) => Container(
                    margin: const EdgeInsets.only(right: 5),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          AssetImage("images/avatar.png"),
                    ),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status == "Planned"
                      ? Colors.green[200]
                      : Colors.orange[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget menuItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text),
    );
  }
}