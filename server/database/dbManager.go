package database

import (
	"context"
	"path/filepath"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"
	"google.golang.org/api/option"
)

/*
Setup the connection between the server and FireBase
*/
func InitializeFirebaseApp() (*firebase.App, error) {
	// Initialize default app
	// TODO: For tests we are in server/tests not server/, leading to the wrong relative path
	accessKeyPath := filepath.FromSlash(`database/accessKey/helenium-798a8-firebase-adminsdk-fbsvc-1e1a23bbbd.json`)
	opt := option.WithCredentialsFile(accessKeyPath)
	conf := &firebase.Config{
		ProjectID: "helenium-798a8",
	}
	app, err := firebase.NewApp(context.Background(), conf, opt)
	if err != nil {
		return nil, err
	}
	return app, nil
}

/*
Setup the Firestore connection for database communication
*/
func AccessFirestoreClient() (*firestore.Client, error) {
	app, err := InitializeFirebaseApp()
	if err != nil {
		return nil, err
	}

	client, err := app.Firestore(context.Background())
	return client, err
}

/*
Creates a document with a random ID and stores it in the database
*/
func CreateDocumentRandomId(client *firestore.Client, ctx context.Context, collection string, input map[string]interface{}) (string, error) {
	doc, _, err := client.Collection(collection).Add(ctx, input)
	return doc.ID, err
}

/*
Creates a document in a certain collection and adds a JSON file
*/
// It is the users responsibility to create a JSON to send as input
func CreateDocument(client *firestore.Client, ctx context.Context, collection string, id string, input map[string]interface{}) error {
	_, err := client.Collection(collection).Doc(id).Set(ctx, input)
	return err
}

/*
Reads a document from a certain collection in the database
*/
func ReadDocument(client *firestore.Client, ctx context.Context, collection string, id string) (map[string]interface{}, error) {
	document, err := client.Collection(collection).Doc(id).Get(ctx)
	return document.Data(), err
}

/*
If the document does not exist, it will be created. If the document exist, it will be merged.
Overwriting all matching fields in the previous entry aswell as appending everything else
*/
func UpdateDocument(client *firestore.Client, ctx context.Context, collection string, id string, newDoc map[string]interface{}) error {
	_, err := client.Collection(collection).Doc(id).Set(ctx, newDoc, firestore.MergeAll) //TODO: Might be issues here down the line
	return err
}

/*
Deletes a specific document in a specific collection
*/
func DeleteDocument(client *firestore.Client, ctx context.Context, collection string, id string) (map[string]interface{}, error) {
	doc := client.Collection(collection).Doc(id)
	toBeDeleted, err := doc.Get(ctx)
	if err != nil {
		return nil, err
	}
	deleted := toBeDeleted.Data()
	_, err = doc.Delete(ctx)
	return deleted, err
}

// Gets the top 10 users with highest scores and puts them in an array of mappings
func GetLeaderboard(client *firestore.Client, ctx context.Context, collection string) ([]map[string]interface{}, error) {
	var result []map[string]interface{}
	iter := client.Collection(collection).OrderBy("Points", firestore.Desc).Limit(10).Documents(ctx)
	docs, err := iter.GetAll()
	if err != nil {
		return nil, err
	}
	for _, doc := range docs {
		result = append(result, doc.Data())
	}
	return result, nil
}

func ReadDisplayName(client *firestore.Client, ctx context.Context, collection string, name string) (string, error) {
	docs, err := client.Collection(collection).Where("DisplayName", "==", name).Documents(ctx).GetAll()
	if len(docs) != 0 {
		return docs[0].Ref.ID, err
	} else {
		return "", err
	}
}
