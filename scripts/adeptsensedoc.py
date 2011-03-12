import inspect


def document(obj):
    """Return documentation string. Shorten to max. 30 lines."""
    doc = obj.__doc__ or ""
    doc_lines = [l.replace(8*' ', 4*' ') for l in doc.split('\n')]
    if len(doc_lines) > 30:
        doc = "\\n".join(doc_lines[0:30]) + '\\n[...]\\n'
    else:
        doc = "\\n".join(doc_lines)
    return doc


def save(name, api, tags):
    """Save generated apidoc and tags."""
    lua_tags_outer = "_m.python.load_completions{%s}"
    lua_tags_entry = """['%s'] = {
    functions = { %s },
    fields = { %s }},
    """

    entries = ""

    for k, v in tags.iteritems():
        functions = ', '.join(["'%s?2'" % s for s in v['functions']])
        fields = ', '.join(["'%s?1'" % s for s in v['fields']])
        entries += lua_tags_entry % (k, functions, fields)

    lua_tags = lua_tags_outer % entries

    f = open('../tags/%s' % name, 'wb')
    f.write(lua_tags)
    f.close()

    f = open('../api/%s' % name, 'wb')
    f.write(api)
    f.close()


def main(module_list, save_to=False):
    tags = {}
    api = ""
    for module_name in module_list:
        tags[module_name] = {'functions': [], 'fields': []}
        try:
            imported = __import__(module_name)
            content = dir(imported)
            for item in content:
                obj = getattr(imported, item)
                # Functions
                if inspect.isbuiltin(obj) or inspect.isfunction(obj):
                    tags[module_name]['functions'].append(item)
                    doc = document(obj)
                    api += "%s %s.%s\\n%s\n" % (item, module_name, item, doc)
                # Classes
                elif inspect.isclass(obj):
                    class_name = obj.__name__
                    doc = document(obj)
                    api += "%s %s.%s\\n%s\n" % (class_name, module_name,
                                                class_name, doc)
                    tags[module_name]['fields'].append(class_name)
                    container = module_name + "." + class_name
                    tags[container] = {'functions': [], 'fields': []}
                    for cl_item in obj.__dict__:
                        cl_kind = getattr(obj, cl_item)
                        if inspect.ismethod(cl_kind):
                            doc = document(cl_kind)
                            api += "%s %s.%s()\\n%s\n" % (cl_kind.__name__,
                                                          class_name,
                                                          cl_kind.__name__,
                                                          doc)
                            tags[container]['functions'].append(cl_item)
                        else:
                            tags[container]['fields'].append(cl_item)
                # Submodules
                elif inspect.ismodule(obj):
                    doc = document(obj)
                    api += "%s %s.%s\\n%s\n" % (item, module_name, item, doc)
                    tags[module_name]['fields'].append(item)
                # Constants
                else:
                    tags[module_name]['fields'].append(item)
                if not save_to:
                    save(module_name, api, tags)
            if save_to:
                save(save_to, api, tags)
            print module_name, 'finished.'
        except:
            print module_name, 'failed'


if __name__ == '__main__':
    import os
    import sys
    def ensure_dir(name):
        if not os.path.exists(name):
            os.makedirs(name)

    ensure_dir('../api')
    ensure_dir('../tags')
    if len(sys.argv) == 1:
        print("Usage:")
        print("python adeptsensedoc.py modulename ...")
        print("python adeptsensedoc.py stdlib")
        print("\nGenerate adeptsense apidoc and tags" +
              " for modules or standard library.")
    elif len(sys.argv) == 2 and sys.argv[1] == 'stdlib':
        from module_list import module_list
        main(module_list, save_to="stdlib")
    else:
        main(sys.argv[1:])
