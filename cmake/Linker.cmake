macro(TextEditWithClangCodeCompletion_configure_linker project_name)
  set(TextEditWithClangCodeCompletion_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(TextEditWithClangCodeCompletion_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE TextEditWithClangCodeCompletion_USER_LINKER_OPTION PROPERTY STRINGS ${TextEditWithClangCodeCompletion_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    TextEditWithClangCodeCompletion_USER_LINKER_OPTION_VALUES
    ${TextEditWithClangCodeCompletion_USER_LINKER_OPTION}
    TextEditWithClangCodeCompletion_USER_LINKER_OPTION_INDEX)

  if(${TextEditWithClangCodeCompletion_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${TextEditWithClangCodeCompletion_USER_LINKER_OPTION}', explicitly supported entries are ${TextEditWithClangCodeCompletion_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${TextEditWithClangCodeCompletion_USER_LINKER_OPTION}")
endmacro()
