import 'package:flutter/material.dart';

/// Modello di categoria
class PlaceCategory {
  final String name;
  final String icon;
  final Color color;

  const PlaceCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Lista di categorie (utilizzata in entrambi i widget)
final List<PlaceCategory> placeCategories = [
  PlaceCategory(name: "Spazio aperto", icon: "🌾", color: Colors.green),
  PlaceCategory(name: "Zona urbana", icon: "🏙️", color: Colors.grey),
  PlaceCategory(name: "Zona naturale", icon: "🌲", color: Colors.teal),
  PlaceCategory(name: "Zona Cinematic", icon: "🏭", color: Colors.brown),
  PlaceCategory(name: "Zona freestyle", icon: "🌀", color: Colors.deepPurple),
  PlaceCategory(name: "Zona Indoor", icon: "🏟️", color: Colors.blueGrey),
  PlaceCategory(name: "Zona vietata", icon: "🚫", color: Colors.red),
  PlaceCategory(name: "Zona Panoramica", icon: "🌄", color: Colors.indigo),
  PlaceCategory(name: "Racing", icon: "🌄", color: Colors.deepPurple),
];

const PlaceCategory allCategory =
PlaceCategory(name: "Tutte", icon: "🔍", color: Colors.blue);
const PlaceCategory superPlaceCategory =
PlaceCategory(name: "Super Place", icon: "⭐", color: Colors.amber);


/// Widget per la selezione orizzontale (es. per scorrere le chip nei filtri)
class CategoryGrid extends StatefulWidget {
  final PlaceCategory? selected;
  final Function(PlaceCategory) onSelected;
  // Lista opzionale di categorie, se non passata si usa quella di default
  final List<PlaceCategory>? categories;

  const CategoryGrid({
    Key? key,
    required this.selected,
    required this.onSelected,
    this.categories,
  }) : super(key: key);

  @override
  State<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<CategoryGrid> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _scrollToSelected() {
    if (widget.selected == null) return;
    final categoriesToShow = widget.categories ??
        [allCategory, superPlaceCategory, ...placeCategories];
    final index = categoriesToShow.indexWhere(
          (c) => c.name == widget.selected!.name,
    );
    if (index >= 0) {
      final offset = (index + 1) * 140.0;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesToShow = widget.categories ??
        [allCategory, superPlaceCategory, ...placeCategories];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      // Se è attiva la tastiera, rendiamo invisibile il widget
      opacity: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 1,
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: categoriesToShow.length,
          padding: const EdgeInsets.symmetric(horizontal: 45),
          itemBuilder: (context, index) {
            final category = categoriesToShow[index];
            final isSelected = widget.selected?.name == category.name;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        category.name,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                selectedColor: category.color.withOpacity(0.2),
                backgroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: TextStyle(
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? category.color : Colors.black87,
                ),
                onSelected: (_) => widget.onSelected(category),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}


/// Widget per la selezione singola in modalità griglia (utilizzato nello step 1 del wizard)
class CategoryGridView extends StatefulWidget {
  final List<PlaceCategory> categories;
  final PlaceCategory? selected;
  final Function(PlaceCategory) onSelected;

  const CategoryGridView({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  _CategoryGridViewState createState() => _CategoryGridViewState();
}

class _CategoryGridViewState extends State<CategoryGridView> {
  PlaceCategory? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.categories.length,
      itemBuilder: (context, index) {
        final category = widget.categories[index];
        final isSelected = selected?.name == category.name;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => selected = category);
              widget.onSelected(category);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isSelected
                    ? category.color.withOpacity(0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? category.color : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              // Aggiungo dei constraint per ridimensionare il chip
              constraints: const BoxConstraints(
                minHeight: 40,
                minWidth: 100,
              ),
              child: Center(
                child: Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? category.color : Colors.black87,
                  ),
                  softWrap: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


/// Widget per il filtro in mappa in modalità multi‑selezione.
class MultiSelectCategoryGrid extends StatefulWidget {
  /// Lista di categorie selezionate attualmente.
  final List<PlaceCategory> selected;
  /// Callback chiamata ogni volta che si clicca una chip, per effettuare il toggle:
  /// se la categoria è già presente viene rimossa, altrimenti aggiunta.
  final Function(PlaceCategory) onToggle;
  /// Lista opzionale di categorie da visualizzare.
  final List<PlaceCategory>? categories;

  const MultiSelectCategoryGrid({
    Key? key,
    required this.selected,
    required this.onToggle,
    this.categories,
  }) : super(key: key);

  @override
  State<MultiSelectCategoryGrid> createState() =>
      _MultiSelectCategoryGridState();
}

class _MultiSelectCategoryGridState extends State<MultiSelectCategoryGrid> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Se esiste almeno una categoria selezionata possiamo scrollare verso la prima
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _scrollToSelected() {
    if (widget.selected.isEmpty) return;
    final categoriesToShow = widget.categories ??
        [allCategory, superPlaceCategory, ...placeCategories];
    // Prendiamo la prima categoria selezionata per scrollare
    final index = categoriesToShow
        .indexWhere((c) => c.name == widget.selected.first.name);
    if (index >= 0) {
      final offset = (index + 1) * 140.0;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesToShow = widget.categories ??
        [allCategory, superPlaceCategory, ...placeCategories];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 1,
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: categoriesToShow.length,
          padding: const EdgeInsets.symmetric(horizontal: 45),
          itemBuilder: (context, index) {
            final category = categoriesToShow[index];
            // Verifica se la categoria è già selezionata
            final isSelected =
            widget.selected.any((c) => c.name == category.name);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        category.name,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                selectedColor: category.color.withOpacity(0.2),
                backgroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle: TextStyle(
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? category.color : Colors.black87,
                ),
                onSelected: (_) => widget.onToggle(category),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
