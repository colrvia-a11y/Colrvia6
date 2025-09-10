import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/features/roller/palette_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';

Paint _p(String id,double l,{double c=10,double h=30,String brand='B'}){
  final lab=[l,c/2,c/2];
  final lch=[l,c,h];
  return Paint(
    id:id,
    brandId:brand.toLowerCase(),
    brandName:brand,
    name:id,
    code:id,
    hex:'#FFFFFF',
    rgb: const [255,255,255],
    lab:lab,
    lch:lch,
    lrv:l,
    finish:'matte',
    collection:'Test'
  );
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Anchor chooses global darkest even with diversity',() async {
    final pool=<Paint>[
      _p('dark5',5,brand:'A'),
      _p('dark7',7,brand:'B'),
      for(int i=0;i<20;i++) _p('L$i',80 + (i%5), c:12 + (i%4), h:(i*17)%360, brand:'C${i%3}')
    ];
    final service=PaletteService();
    final rolled= await service.generate(
      available: pool,
      anchors: List.filled(2,null),
      diversifyBrands: true,
      mode: HarmonyMode.colrvia,
    );
    expect(rolled.length,2);
    final lvals=rolled.map((p)=>p.computedLrv).toList()..sort();
    // Expect one very dark (<15) and it should be 5 not 7 if no lock present
    expect(lvals.first < 15, isTrue);
    final darkest= rolled.reduce((a,b)=> a.computedLrv < b.computedLrv ? a : b);
    expect(darkest.computedLrv,5); // darkest-first guarantee
  });
}
