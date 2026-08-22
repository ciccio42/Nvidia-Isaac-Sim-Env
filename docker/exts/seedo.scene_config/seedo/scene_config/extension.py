import builtins
import omni.ext


SERVER_SCRIPT = "/workspace/isaac_tools/isaac_scene_config_server.py"
SERVER_INSTANCE = "_seedo_isaac_scene_config_server"


class SeeDoSceneConfigExtension(omni.ext.IExt):

    def on_startup(self, ext_id):
        print()
        print("==============================================")
        print("Starting SeeDo Scene Configuration extension")
        print("==============================================")

        try:
            with open(SERVER_SCRIPT, "r") as f:
                source = f.read()

            namespace = {
                "__name__": "__seedo_scene_config_server__",
                "__file__": SERVER_SCRIPT,
            }

            exec(
                compile(
                    source,
                    SERVER_SCRIPT,
                    "exec",
                ),
                namespace,
            )

            print(
                "[SeeDo Extension] "
                "Scene configuration server started automatically."
            )

        except Exception as exc:
            print(
                "[SeeDo Extension] "
                f"ERROR while starting server: {exc}"
            )
            raise

    def on_shutdown(self):
        print(
            "[SeeDo Extension] "
            "Shutting down scene configuration server..."
        )

        server = getattr(
            builtins,
            SERVER_INSTANCE,
            None,
        )

        if server is not None:
            try:
                server.shutdown()
            except Exception as exc:
                print(
                    "[SeeDo Extension] "
                    f"Shutdown warning: {exc}"
                )

            try:
                delattr(
                    builtins,
                    SERVER_INSTANCE,
                )
            except Exception:
                pass

        print(
            "[SeeDo Extension] "
            "Scene configuration server stopped."
        )
