import { addShortcutsExtension } from '~/behaviors/shortcuts';
import ShortcutsNavigation from '~/behaviors/shortcuts/shortcuts_navigation';
import Project from './project';

new Project(); // eslint-disable-line no-new
addShortcutsExtension(ShortcutsNavigation);
