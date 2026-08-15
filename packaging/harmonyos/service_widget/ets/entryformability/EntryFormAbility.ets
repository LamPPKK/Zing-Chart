import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';

const STORE = 'zingchart_companion';

export default class EntryFormAbility extends FormExtensionAbility {
  async onAddForm(want: Want): Promise<formBindingData.FormBindingData> {
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;
    const store = await preferences.getPreferences(this.context, { name: STORE });
    const formIds = new Set(
      JSON.parse(await store.get('formIds', '[]') as string) as string[]
    );
    formIds.add(formId);
    await store.put('formIds', JSON.stringify(Array.from(formIds)));
    await store.flush();
    const snapshot = JSON.parse(
      await store.get('playerSnapshot', '{"title":"#zingChart","artist":"","isPlaying":false}') as string
    ) as Record<string, Object>;
    return formBindingData.createFormBindingData(snapshot);
  }

  async onRemoveForm(formId: string): Promise<void> {
    const store = await preferences.getPreferences(this.context, { name: STORE });
    const formIds = new Set(
      JSON.parse(await store.get('formIds', '[]') as string) as string[]
    );
    formIds.delete(formId);
    await store.put('formIds', JSON.stringify(Array.from(formIds)));
    await store.flush();
  }

  async onFormEvent(formId: string, message: string): Promise<void> {
    const action = (JSON.parse(message) as Record<string, string>).action;
    if (!['previous', 'togglePlayPause', 'next'].includes(action)) return;
    await this.context.startAbility({
      bundleName: 'software.baycho.zmp3chart',
      abilityName: 'EntryAbility',
      parameters: { companionAction: action }
    });
  }
}
