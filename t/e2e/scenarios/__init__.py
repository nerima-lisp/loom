"""Import every scenario module so its @scenario registrations run."""

from . import cli  # noqa: F401
from . import startup  # noqa: F401
from . import editing  # noqa: F401
from . import macros  # noqa: F401
from . import modes  # noqa: F401
from . import project  # noqa: F401
from . import movement  # noqa: F401
from . import editing_commands  # noqa: F401
from . import files  # noqa: F401
from . import file_tree  # noqa: F401
from . import windows  # noqa: F401
from . import session  # noqa: F401
from . import tooling  # noqa: F401
from . import lsp  # noqa: F401
from . import macros_extended  # noqa: F401
from . import ui  # noqa: F401
from . import remaining  # noqa: F401
