"""Architecture checks for GPS isolation; complements Swift tests and device acceptance checks."""
from pathlib import Path
import re
import unittest
root = Path(__file__).resolve().parent.parent
view = (root / 'Geranium/LocSim/RouteSimView.swift').read_text(encoding='utf-8')
main = (root / 'Geranium/LocSim/LocSimView.swift').read_text(encoding='utf-8')
simulator = (root / 'Geranium/LocSim/RouteSimulator.swift').read_text(encoding='utf-8')
map_source = (root / 'Geranium/LocSim/CustomMapView.swift').read_text(encoding='utf-8')

def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]

class NavigationSafetyTests(unittest.TestCase):
    def test_draft_editor_has_no_simulator_or_gps_binding(self):
        picker = view.split('private struct RoutePointPicker:', 1)[1]
        for forbidden in ['LocSimManager.', 'RouteSimulator()', 'startSimulation(', 'stopSimulation(', 'tappedCoordinate']:
            self.assertNotIn(forbidden, picker)
        self.assertIn('parent.selection = map.convert', picker)
        self.assertIn('onSelect(coordinate)', picker)

    def test_selection_and_search_cannot_start_gps(self):
        planning = section(view, 'private func selectMapPoint(', 'private func startRoute(')
        self.assertNotIn('startSimulation(', planning)
        self.assertNotIn('LocSimManager.', planning)
        # Navigation has exactly one simulation start call, in the explicit button action.
        self.assertEqual(view.count('routeSimulator.startSimulation('), 1)
        self.assertIn('Button(action: startRoute)', view)
        self.assertIn('guard routeReady, !routeSimulator.isCalculatingRoute', view)

    def test_background_map_blocks_teleport(self):
        handler = section(main, '.onChange(of: tappedCoordinate)', '.ignoresSafeArea')
        self.assertIn('guard !showRouteSheet', handler)
        self.assertIn('.allowsHitTesting(!showRouteSheet)', main)

    def test_preview_is_read_only(self):
        self.assertIn('acceptsTaps: false', view)
        self.assertIn('guard parent.acceptsTaps else { return }', map_source)
        self.assertIn('tappedCoordinate: .constant(nil)', view)

    def test_cancel_and_clear_preview_do_not_stop_existing_gps(self):
        clear = section(simulator, 'func cancelRouteCalculation()', 'func updateSpeedMultiplier(')
        self.assertNotIn('LocSimManager.', clear)
        self.assertNotIn('stopSimulation(', clear)
        self.assertIn('requestGate.invalidate()', clear)
        calculate = section(simulator, 'func calculateRoutes(', 'func cancelRouteCalculation()')
        self.assertIn('requestGate.accepts(requestID)', calculate)
        self.assertNotIn('startSimulation(', calculate)

if __name__ == '__main__':
    unittest.main()
