import 'dart:io';

import 'package:askaide/bloc/model_bloc.dart';
import 'package:askaide/helper/upload.dart';
import 'package:askaide/lang/lang.dart';
import 'package:askaide/page/component/avatar_selector.dart';
import 'package:askaide/page/component/background_container.dart';
import 'package:askaide/page/component/column_block.dart';
import 'package:askaide/page/component/dialog.dart';
import 'package:askaide/page/component/enhanced_button.dart';
import 'package:askaide/page/component/enhanced_input.dart';
import 'package:askaide/page/component/enhanced_textfield.dart';
import 'package:askaide/page/component/image.dart';
import 'package:askaide/page/component/item_selector_search.dart';
import 'package:askaide/page/component/loading.dart';
import 'package:askaide/page/component/random_avatar.dart';
import 'package:askaide/page/component/theme/custom_size.dart';
import 'package:askaide/page/component/theme/custom_theme.dart';
import 'package:askaide/page/component/weak_text_button.dart';
import 'package:askaide/repo/api/admin/channels.dart';
import 'package:askaide/repo/api/admin/models.dart';
import 'package:askaide/repo/api_server.dart';
import 'package:askaide/repo/settings_repo.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/models/quickalert_type.dart';

class AdminModelEditPage extends StatefulWidget {
  final SettingRepository setting;
  final String modelId;
  const AdminModelEditPage({
    super.key,
    required this.setting,
    required this.modelId,
  });

  @override
  State<AdminModelEditPage> createState() => _AdminModelEditPageState();
}

class _AdminModelEditPageState extends State<AdminModelEditPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController modelIdController = TextEditingController();
  final TextEditingController shortNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController maxContextController = TextEditingController();
  final TextEditingController inputPriceController = TextEditingController();
  final TextEditingController outputPriceController = TextEditingController();
  final TextEditingController promptController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  /// 用于控制是否显示高级选项
  bool showAdvancedOptions = false;

  /// 视觉能力
  bool supportVision = false;

  /// 受限模型
  bool restricted = false;

  /// 模型状态
  bool modelEnabled = true;

  /// 是否是上新
  bool isNew = false;

  /// Tag
  final TextEditingController tagController = TextEditingController();
  String? tagTextColor;
  String? tagBgColor;

  /// 模型头像
  String? avatarUrl;
  List<String> avatarPresets = [];

  // 模型渠道
  List<AdminChannel> modelChannels = [];
  // 选择的渠道
  List<AdminModelProvider> providers = [];

  /// 是否锁定编辑
  bool editLocked = true;

  @override
  void dispose() {
    nameController.dispose();
    modelIdController.dispose();
    shortNameController.dispose();
    descriptionController.dispose();
    maxContextController.dispose();
    inputPriceController.dispose();
    outputPriceController.dispose();
    promptController.dispose();
    categoryController.dispose();
    tagController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    // 加载预设头像
    APIServer().avatars().then((value) {
      avatarPresets = value;
    });
    // 加载模型渠道
    APIServer().adminChannelsAgg().then((value) {
      setState(() {
        modelChannels = value;
      });

      // 加载模型
      context.read<ModelBloc>().add(ModelLoadEvent(widget.modelId));
    });

    // 初始值设置
    maxContextController.value = const TextEditingValue(text: '7500');
    inputPriceController.value = const TextEditingValue(text: '0');
    outputPriceController.value = const TextEditingValue(text: '0');

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: CustomSize.toolbarHeight,
        title: const Text(
          'Edit Model',
          style: TextStyle(fontSize: CustomSize.appBarTitleSize),
        ),
        centerTitle: true,
      ),
      backgroundColor: customColors.backgroundColor,
      body: BackgroundContainer(
        setting: widget.setting,
        enabled: false,
        child: SingleChildScrollView(
          child: BlocListener<ModelBloc, ModelState>(
            listenWhen: (previous, current) => current is ModelOperationResult || current is ModelLoaded,
            listener: (context, state) {
              if (state is ModelOperationResult) {
                if (state.success) {
                  showSuccessMessage(state.message);
                  context.read<ModelBloc>().add(ModelLoadEvent(widget.modelId));
                } else {
                  showErrorMessage(state.message);
                }
              }

              if (state is ModelLoaded) {
                modelIdController.value = TextEditingValue(text: state.model.modelId);
                nameController.value = TextEditingValue(text: state.model.name);
                if (state.model.description != null) {
                  descriptionController.value = TextEditingValue(text: state.model.description!);
                }

                if (state.model.avatarUrl != null) {
                  avatarUrl = state.model.avatarUrl;
                }

                modelEnabled = state.model.status == 1;

                if (state.model.providers.isNotEmpty) {
                  providers = state.model.providers;
                }

                if (state.model.meta != null) {
                  if (state.model.meta!.maxContext != null) {
                    maxContextController.value = TextEditingValue(text: state.model.meta!.maxContext.toString());
                  }

                  if (state.model.meta!.inputPrice != null) {
                    inputPriceController.value = TextEditingValue(text: state.model.meta!.inputPrice.toString());
                  }

                  if (state.model.meta!.outputPrice != null) {
                    outputPriceController.value = TextEditingValue(text: state.model.meta!.outputPrice.toString());
                  }

                  promptController.value = TextEditingValue(text: state.model.meta!.prompt ?? '');
                  supportVision = state.model.meta!.vision ?? false;
                  restricted = state.model.meta!.restricted ?? false;
                  tagController.value = TextEditingValue(text: state.model.meta!.tag ?? '');
                  tagTextColor = state.model.meta!.tagTextColor;
                  tagBgColor = state.model.meta!.tagBgColor;
                  isNew = state.model.meta!.isNew ?? false;
                  categoryController.value = TextEditingValue(text: state.model.meta!.category ?? '');
                }
              }

              setState(() {
                editLocked = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 20),
              child: Column(
                children: [
                  ColumnBlock(
                    children: [
                      EnhancedTextField(
                        labelText: 'ID',
                        customColors: customColors,
                        controller: modelIdController,
                        textAlignVertical: TextAlignVertical.top,
                        hintText: 'Enter a unique ID',
                        maxLength: 100,
                        showCounter: false,
                        readOnly: true,
                      ),
                      EnhancedTextField(
                        labelText: 'Vendor',
                        customColors: customColors,
                        controller: categoryController,
                        textAlignVertical: TextAlignVertical.top,
                        hintText: 'Enter a vendor name (Optional)',
                        maxLength: 100,
                        showCounter: false,
                      ),
                      EnhancedTextField(
                        labelText: 'Name',
                        customColors: customColors,
                        controller: nameController,
                        textAlignVertical: TextAlignVertical.top,
                        hintText: 'Enter a model name',
                        maxLength: 100,
                        showCounter: false,
                      ),
                      EnhancedInput(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        title: Text(
                          'Avatar',
                          style: TextStyle(
                            color: customColors.textfieldLabelColor,
                            fontSize: 16,
                          ),
                        ),
                        value: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                borderRadius: CustomSize.borderRadius,
                                image: avatarUrl == null
                                    ? null
                                    : DecorationImage(
                                        image: (avatarUrl!.startsWith('http')
                                            ? CachedNetworkImageProviderEnhanced(avatarUrl!)
                                            : FileImage(File(avatarUrl!))) as ImageProvider,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              child: avatarUrl == null
                                  ? const Center(
                                      child: Icon(
                                        Icons.interests,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                        onPressed: () {
                          openModalBottomSheet(
                            context,
                            (context) {
                              return AvatarSelector(
                                onSelected: (selected) {
                                  setState(() {
                                    avatarUrl = selected.url;
                                  });
                                  context.pop();
                                },
                                usage: AvatarUsage.user,
                                defaultAvatarUrl: avatarUrl,
                                externalAvatarUrls: [
                                  ...avatarPresets,
                                ],
                              );
                            },
                            heightFactor: 0.8,
                          );
                        },
                      ),
                      EnhancedTextField(
                        labelText: 'Description',
                        customColors: customColors,
                        controller: descriptionController,
                        textAlignVertical: TextAlignVertical.top,
                        hintText: 'Optional',
                        maxLength: 255,
                        showCounter: false,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  ColumnBlock(
                    children: [
                      EnhancedTextField(
                        labelWidth: 120,
                        labelText: 'Input Price',
                        customColors: customColors,
                        controller: inputPriceController,
                        textAlignVertical: TextAlignVertical.top,
                        hintText: 'Optional',
                        showCounter: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textDirection: TextDirection.rtl,
                        suffixIcon: Container(
                          width: 110,
                          alignment: Alignment.center,
                          child: Text(
                            'Credits/1K Token',
                            style: TextStyle(color: customColors.weakTextColor, fontSize: 12),
                          ),
                        ),
                      ),
                      EnhancedTextField(
                        labelWidth: 120,
                        labelText: 'Output Price',
                        customColors: customColors,
                        controller: outputPriceController,
                        textAlignVertical: TextAlignVertical.top,
                        hintText: 'Optional',
                        showCounter: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textDirection: TextDirection.rtl,
                        suffixIcon: Container(
                          width: 110,
                          alignment: Alignment.center,
                          child: Text(
                            'Credits/1K Token',
                            style: TextStyle(color: customColors.weakTextColor, fontSize: 12),
                          ),
                        ),
                      ),
                      EnhancedTextField(
                        labelText: 'Context Length',
                        customColors: customColors,
                        controller: maxContextController,
                        textAlignVertical: TextAlignVertical.top,
                        hintText: 'Subtract the expected output length from the maximum context.',
                        showCounter: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textDirection: TextDirection.rtl,
                        suffixIcon: Container(
                          width: 50,
                          alignment: Alignment.center,
                          child: Text(
                            'Token',
                            style: TextStyle(color: customColors.weakTextColor, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (var i = 0; i < providers.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
                      child: Slidable(
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            const SizedBox(width: 10),
                            SlidableAction(
                              label: AppLocale.delete.getString(context),
                              borderRadius: CustomSize.borderRadiusAll,
                              backgroundColor: Colors.red,
                              icon: Icons.delete,
                              onPressed: (_) {
                                if (providers.length == 1) {
                                  showErrorMessage('At least one channel is needed');
                                  return;
                                }

                                openConfirmDialog(
                                  context,
                                  AppLocale.confirmToDeleteRoom.getString(context),
                                  () {
                                    setState(() {
                                      providers.removeAt(i);
                                    });
                                  },
                                  danger: true,
                                );
                              },
                            ),
                          ],
                        ),
                        child: ColumnBlock(
                          margin: const EdgeInsets.all(0),
                          children: [
                            EnhancedInput(
                              title: Text(
                                'Channel',
                                style: TextStyle(
                                  color: customColors.textfieldLabelColor,
                                  fontSize: 16,
                                ),
                              ),
                              value: Text(
                                buildChannelName(providers[i]),
                                style: TextStyle(
                                  color: customColors.textfieldValueColor,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () {
                                openListSelectDialog(
                                  context,
                                  <SelectorItem<AdminChannel>>[
                                    ...modelChannels
                                        .map(
                                          (e) => SelectorItem(
                                            Text('${e.id == null ? '【System】' : ''}${e.name}'),
                                            e,
                                          ),
                                        )
                                        .toList(),
                                  ],
                                  (value) {
                                    setState(() {
                                      providers[i].id = value.value.id;
                                      if (value.value.id == null) {
                                        providers[i].name = value.value.type;
                                      }
                                    });
                                    return true;
                                  },
                                  heightFactor: 0.5,
                                  value: providers[i],
                                );
                              },
                            ),
                            EnhancedTextField(
                              labelWidth: 120,
                              labelText: 'Model Rewrite',
                              labelFontSize: 12,
                              customColors: customColors,
                              textAlignVertical: TextAlignVertical.top,
                              hintText: 'Optional',
                              maxLength: 100,
                              showCounter: false,
                              initValue: providers[i].modelRewrite,
                              onChanged: (value) {
                                setState(() {
                                  providers[i].modelRewrite = value;
                                });
                              },
                              labelHelpWidget: InkWell(
                                onTap: () {
                                  showBeautyDialog(
                                    context,
                                    type: QuickAlertType.info,
                                    text:
                                        'When the model identifier corresponding to the channel does not match the ID here, calling the channel interface will automatically replace the model with the value configured here.',
                                    confirmBtnText: AppLocale.gotIt.getString(context),
                                    showCancelBtn: false,
                                  );
                                },
                                child: Icon(
                                  Icons.help_outline,
                                  size: 16,
                                  color: customColors.weakLinkColor?.withAlpha(150),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  WeakTextButton(
                    title: 'Add Channel',
                    icon: Icons.add,
                    onPressed: () {
                      setState(() {
                        providers.add(AdminModelProvider());
                      });
                    },
                  ),
                  // 高级选项
                  if (showAdvancedOptions)
                    ColumnBlock(
                      innerPanding: 5,
                      children: [
                        EnhancedTextField(
                          labelText: 'Abbr.',
                          customColors: customColors,
                          controller: shortNameController,
                          textAlignVertical: TextAlignVertical.top,
                          hintText: 'Enter model shorthand',
                          maxLength: 100,
                          showCounter: false,
                        ),
                        EnhancedTextField(
                          labelText: 'Tag',
                          customColors: customColors,
                          controller: tagController,
                          textAlignVertical: TextAlignVertical.top,
                          hintText: 'Enter tags',
                          maxLength: 100,
                          showCounter: false,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Vision',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 5),
                                InkWell(
                                  onTap: () {
                                    showBeautyDialog(
                                      context,
                                      type: QuickAlertType.info,
                                      text: 'Whether the current model supports visual capabilities.',
                                      confirmBtnText: AppLocale.gotIt.getString(context),
                                      showCancelBtn: false,
                                    );
                                  },
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 16,
                                    color: customColors.weakLinkColor?.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                            CupertinoSwitch(
                              activeColor: customColors.linkColor,
                              value: supportVision,
                              onChanged: (value) {
                                setState(() {
                                  supportVision = value;
                                });
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'New',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 5),
                                InkWell(
                                  onTap: () {
                                    showBeautyDialog(
                                      context,
                                      type: QuickAlertType.info,
                                      text:
                                          'Whether to display a "New" icon next to the model to inform users that this is a new model.',
                                      confirmBtnText: AppLocale.gotIt.getString(context),
                                      showCancelBtn: false,
                                    );
                                  },
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 16,
                                    color: customColors.weakLinkColor?.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                            CupertinoSwitch(
                              activeColor: customColors.linkColor,
                              value: isNew,
                              onChanged: (value) {
                                setState(() {
                                  isNew = value;
                                });
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Restricted',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 5),
                                InkWell(
                                  onTap: () {
                                    showBeautyDialog(
                                      context,
                                      type: QuickAlertType.info,
                                      text:
                                          'Restricted models refer to models that cannot be used in Chinese Mainland due to policy factors.',
                                      confirmBtnText: AppLocale.gotIt.getString(context),
                                      showCancelBtn: false,
                                    );
                                  },
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 16,
                                    color: customColors.weakLinkColor?.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                            CupertinoSwitch(
                              activeColor: customColors.linkColor,
                              value: restricted,
                              onChanged: (value) {
                                setState(() {
                                  restricted = value;
                                });
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Enabled',
                              style: TextStyle(fontSize: 16),
                            ),
                            CupertinoSwitch(
                              activeColor: customColors.linkColor,
                              value: modelEnabled,
                              onChanged: (value) {
                                setState(() {
                                  modelEnabled = value;
                                });
                              },
                            ),
                          ],
                        ),
                        EnhancedTextField(
                          labelPosition: LabelPosition.top,
                          labelText: 'System prompt',
                          customColors: customColors,
                          controller: promptController,
                          textAlignVertical: TextAlignVertical.top,
                          hintText: 'Global system prompt',
                          maxLength: 2000,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      EnhancedButton(
                        title: showAdvancedOptions
                            ? AppLocale.simpleMode.getString(context)
                            : AppLocale.professionalMode.getString(context),
                        width: 120,
                        backgroundColor: Colors.transparent,
                        color: customColors.weakLinkColor,
                        fontSize: 15,
                        icon: Icon(
                          showAdvancedOptions ? Icons.unfold_less : Icons.unfold_more,
                          color: customColors.weakLinkColor,
                          size: 15,
                        ),
                        onPressed: () {
                          setState(() {
                            showAdvancedOptions = !showAdvancedOptions;
                          });
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: EnhancedButton(
                          title: AppLocale.save.getString(context),
                          onPressed: onSubmit,
                          icon: editLocked
                              ? const Icon(Icons.lock, color: Colors.white, size: 16)
                              : const Icon(Icons.lock_open, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 提交
  void onSubmit() async {
    if (editLocked) {
      return;
    }

    if (nameController.text.isEmpty) {
      showErrorMessage('Please enter a model name');
      return;
    }

    final ps = providers.where((e) => e.id != null || e.name != null).toList();
    if (ps.isEmpty) {
      showErrorMessage('At least one channel is required');
      return;
    }

    if (avatarUrl != null && (!avatarUrl!.startsWith('http://') && !avatarUrl!.startsWith('https://'))) {
      final cancel = BotToast.showCustomLoading(
        toastBuilder: (cancel) {
          return const LoadingIndicator(
            message: 'Uploading avatar, please wait...',
          );
        },
        allowClick: false,
      );

      try {
        final res = await ImageUploader(widget.setting).upload(avatarUrl!, usage: 'avatar');
        avatarUrl = res.url;
      } catch (e) {
        showErrorMessage('Failed to upload avatar');
        cancel();
        return;
      } finally {
        cancel();
      }
    }

    final model = AdminModelUpdateReq(
      name: nameController.text,
      description: descriptionController.text,
      shortName: shortNameController.text,
      meta: AdminModelMeta(
        maxContext: int.parse(maxContextController.text),
        inputPrice: int.parse(inputPriceController.text),
        outputPrice: int.parse(outputPriceController.text),
        prompt: promptController.text,
        vision: supportVision,
        restricted: restricted,
        category: categoryController.text,
        tag: tagController.text,
        tagTextColor: tagTextColor,
        tagBgColor: tagBgColor,
        isNew: isNew,
      ),
      status: modelEnabled ? 1 : 2,
      providers: ps,
      avatarUrl: avatarUrl,
    );

    setState(() {
      editLocked = true;
    });

    // ignore: use_build_context_synchronously
    context.read<ModelBloc>().add(ModelUpdateEvent(widget.modelId, model));
  }

  /// 渠道名称
  String buildChannelName(AdminModelProvider provider) {
    if (provider.id != null) {
      return modelChannels.firstWhere((e) => e.id == provider.id).name;
    }

    if (provider.name != null) {
      return modelChannels
          .firstWhere(
            (e) => e.type == provider.name! && e.id == null,
            orElse: () => AdminChannel(name: 'Unknown', type: ''),
          )
          .display;
    }

    return 'Select';
  }
}
