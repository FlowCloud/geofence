DataStore::DataStore(char *_name)
{
	name = _name;
}

bool DataStore::load()
{
	bool result = false;
	FlowMemoryManager memoryManager = FlowMemoryManager_New();
	if (memoryManager)
	{
		FlowDevice thisDevice = FlowClient_GetLoggedInDevice(memoryManager);
		if (thisDevice)
		{
			_datastore = FlowDevice_RetrieveDataStore(thisDevice, name);
			if (_datastore)
			{
				if (FlowMemoryManager_DetachObject(memoryManager, &_datastore))
				{
					result = true;
				}
			}
		}
		FlowMemoryManager_Free(&memoryManager);
	}
	return result;
}

bool DataStore::clear(char *str)
{
	bool result = false;
	FlowMemoryManager memoryManager = FlowMemoryManager_New();
	if (memoryManager && FlowMemoryManager_AttachObject(memoryManager, _datastore))
	{
		FlowDataStoreItems datastoreItems = FlowDataStore_RetrieveItems(_datastore, 0);
		unsigned int measurementCount = FlowDataStoreItems_GetTotalCount(datastoreItems);

		if (datastoreItems && FlowDataStoreItems_Remove(datastoreItems, str))
		{
			Serial.print("\n\rSuccessfully deleted measurement(s).\n\r");
			result = true;
		}
		else
		{
			Serial.print("Error, failed to delete saved measurements.");
		}
		
		FlowMemoryManager_DetachObject(memoryManager, &_datastore);
		FlowMemoryManager_Free(&memoryManager);
	}
	return result;
}

bool DataStore::save(XMLNode &node){
	bool result = false;
	StringBuilder datastoreItem = StringBuilder_New(1024);
	datastoreItem = node.appendTo(datastoreItem);
	
	FlowMemoryManager memoryManager = FlowMemoryManager_New();
	if (memoryManager && FlowMemoryManager_AttachObject(memoryManager, _datastore))
	{
		FlowDataStoreItems datastoreItems = FlowDataStore_RetrieveItems(_datastore, 0);
		if (datastoreItems)
		{
			FlowDataStoreItem newItem = FlowDataStoreItem_New(memoryManager);
			FlowDataStoreItem_SetContent(newItem, (char *) StringBuilder_GetCString(datastoreItem));
			if (FlowDataStoreItems_AddItem(datastoreItems, newItem))
			{
				result = true;
			}
		}

		FlowMemoryManager_DetachObject(memoryManager, &_datastore);
	}

	FlowMemoryManager_Free(&memoryManager);
	StringBuilder_Free(&datastoreItem);
	return result;
}