import 'package:flutter/material.dart';
import 'package:mjeshtri/page/kalkulo_page.dart';
import 'package:mjeshtri/page/parametrat_page.dart';
import 'package:mjeshtri/page/punet_page.dart';
import 'package:mjeshtri/page/punetoret_page.dart';
import 'package:mjeshtri/page/qarkullimi_vjetor_page.dart';
import 'package:mjeshtri/page/qmimore_page.dart';
import 'package:mjeshtri/page/vizato_page.dart';
import 'package:mjeshtri/theme/app_theme.dart';

class MjeshtriApp extends StatelessWidget {
  const MjeshtriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mjeshtri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int idx = 0;

  static const List<Widget> pages = [
    KalkuloPage(),
    ParametratPage(),
    QmimorePage(),
    PunetoretPage(),
    PunetPage(),
    QarkullimiVjetorPage(),
    VizatoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: idx,
            onDestinationSelected: (v) => setState(() => idx = v),
            labelType: NavigationRailLabelType.all,
            minWidth: 88,
            minExtendedWidth: 220,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: Text('Kalkulo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: Text('Parametrat'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.table_chart_outlined),
                selectedIcon: Icon(Icons.table_chart),
                label: Text('Qmimore'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Punëtorët'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.business_center_outlined),
                selectedIcon: Icon(Icons.business_center),
                label: Text('Punët'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Qarkullimi Vjetor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.grading_outlined),
                selectedIcon: Icon(Icons.draw_rounded),
                label: Text('Skica'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IndexedStack(
                index: idx,
                children: pages,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
